import {
  ChatInputCommandInteraction,
  EmbedBuilder,
  GuildMember,
  SlashCommandBuilder,
} from 'discord.js';
import { eq, count, inArray, notInArray } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, licenseOwners, whitelist } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { generateKeys, generateId } from '../utils/keys.js';
import { calcExpiresAt, typeLabel } from '../utils/time.js';
import { sendLog, logEmbed } from '../utils/discord-logger.js';

export const WHITELIST_DEF = new SlashCommandBuilder()
  .setName('whitelist')
  .setDescription('Manajemen whitelist VIP')
  .addSubcommand((s) =>
    s.setName('add').setDescription('Tambahkan user ke whitelist VIP')
      .addUserOption((o) => o.setName('user').setDescription('User Discord').setRequired(true))
      .addIntegerOption((o) =>
        o.setName('key_count').setDescription('Jumlah key yang di-generate (1–50)').setRequired(true).setMinValue(1).setMaxValue(50),
      )
      .addStringOption((o) =>
        o.setName('type').setDescription('Tipe key (default: PERMANENT)')
          .addChoices(
            { name: 'PERMANENT', value: 'PERMANENT' },
            { name: 'HOURLY', value: 'HOURLY' },
            { name: 'DAILY', value: 'DAILY' },
            { name: 'WEEKLY', value: 'WEEKLY' },
          ),
      )
      .addIntegerOption((o) =>
        o.setName('duration').setDescription('Durasi (wajib jika bukan PERMANENT)').setMinValue(1).setMaxValue(9999),
      ),
  )
  .addSubcommand((s) =>
    s.setName('remove').setDescription('Hapus user dari whitelist VIP')
      .addUserOption((o) => o.setName('user').setDescription('User Discord').setRequired(true)),
  )
  .addSubcommand((s) => s.setName('list').setDescription('Tampilkan semua member whitelist VIP'));

export async function whitelist(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }

  const sub = interaction.options.getSubcommand();

  if (sub === 'add') return whitelistAdd(interaction);
  if (sub === 'remove') return whitelistRemove(interaction);
  if (sub === 'list') return whitelistList(interaction);
}

async function whitelistAdd(interaction: ChatInputCommandInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const user = interaction.options.getUser('user', true);
  const keyCount = interaction.options.getInteger('key_count', true);
  const type = (interaction.options.getString('type') ?? 'PERMANENT') as 'PERMANENT' | 'HOURLY' | 'DAILY' | 'WEEKLY';
  const duration = interaction.options.getInteger('duration') ?? null;

  if (type !== 'PERMANENT' && !duration) {
    return interaction.editReply({ content: '❌ `duration` wajib diisi untuk tipe bukan PERMANENT.' });
  }

  // Upsert whitelist
  await db.insert(whitelist).values({ discordUserId: user.id }).onConflictDoNothing();

  const keys = generateKeys(keyCount);
  const expiresAt = calcExpiresAt(type, duration);

  await db.insert(licenses).values(
    keys.map((k) => ({
      key: k,
      type,
      duration,
      expiresAt,
      createdBy: interaction.user.id,
    })),
  );

  await db.insert(licenseOwners).values(
    keys.map((k) => ({ id: generateId(), licenseKey: k, discordUserId: user.id })),
  );

  // Give PREMIUM role if PERMANENT
  if (type === 'PERMANENT' && interaction.guild) {
    try {
      const member = await interaction.guild.members.fetch(user.id);
      const premiumRoleName = process.env.PREMIUM_ROLE_NAME ?? 'PREMIUM';
      const role = interaction.guild.roles.cache.find((r) => r.name === premiumRoleName);
      if (role) await member.roles.add(role);
      await db.update(whitelist).set({ claimedVip: true }).where(eq(whitelist.discordUserId, user.id));
    } catch {}
  }

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('✅ User Ditambahkan ke Whitelist VIP')
    .addFields(
      { name: 'User', value: `<@${user.id}>`, inline: true },
      { name: 'Key di-generate', value: `${keyCount}`, inline: true },
      { name: 'Tipe', value: typeLabel(type, duration), inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
  await sendLog(logEmbed('✅ Whitelist Ditambah', 0x2ecc71).addFields(
    { name: 'User', value: `<@${user.id}>`, inline: true },
    { name: 'Oleh', value: `<@${interaction.user.id}>`, inline: true },
    { name: 'Key', value: `${keyCount}x ${typeLabel(type, duration)}`, inline: true },
  ));
}

async function whitelistRemove(interaction: ChatInputCommandInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const user = interaction.options.getUser('user', true);

  const [entry] = await db.select().from(whitelist).where(eq(whitelist.discordUserId, user.id));
  if (!entry) return interaction.editReply({ content: `❌ User <@${user.id}> tidak terdaftar di whitelist.` });

  // Get all keys owned by this user
  const owned = await db.select().from(licenseOwners).where(eq(licenseOwners.discordUserId, user.id));
  const keys = owned.map((o) => o.licenseKey);

  if (keys.length > 0) {
    // Remove ownership records for this user only
    await db.delete(licenseOwners).where(eq(licenseOwners.discordUserId, user.id));

    // Find keys that still have other owners — keep those licenses intact
    const stillOwned = await db
      .select({ licenseKey: licenseOwners.licenseKey })
      .from(licenseOwners)
      .where(inArray(licenseOwners.licenseKey, keys));

    const stillOwnedKeys = stillOwned.map((o) => o.licenseKey);

    // Delete only licenses that are now orphaned (no remaining owners)
    const orphanedKeys = stillOwnedKeys.length > 0
      ? keys.filter((k) => !stillOwnedKeys.includes(k))
      : keys;

    if (orphanedKeys.length > 0) {
      await db.delete(licenses).where(inArray(licenses.key, orphanedKeys));
    }
  }

  await db.delete(whitelist).where(eq(whitelist.discordUserId, user.id));

  // Remove roles
  if (interaction.guild) {
    try {
      const member = await interaction.guild.members.fetch(user.id);
      const premiumRoleName = process.env.PREMIUM_ROLE_NAME ?? 'PREMIUM';
      const premiumRole = interaction.guild.roles.cache.find((r) => r.name === premiumRoleName);
      const vipRole = interaction.guild.roles.cache.find((r) => r.name === 'VIP');
      if (premiumRole) await member.roles.remove(premiumRole).catch(() => {});
      if (vipRole) await member.roles.remove(vipRole).catch(() => {});
    } catch {}
  }

  const embed = new EmbedBuilder()
    .setColor(0xe74c3c)
    .setTitle('🗑️ User Dihapus dari Whitelist VIP')
    .addFields(
      { name: 'User', value: `<@${user.id}>`, inline: true },
      { name: 'Key Dihapus', value: `${owned.length}`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
  await sendLog(logEmbed('🗑️ Whitelist Dihapus', 0xe74c3c).addFields(
    { name: 'User', value: `<@${user.id}>`, inline: true },
    { name: 'Oleh', value: `<@${interaction.user.id}>`, inline: true },
  ));
}

async function whitelistList(interaction: ChatInputCommandInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();

  const entries = await db.select().from(whitelist).limit(25);

  if (entries.length === 0) {
    return interaction.editReply({ content: 'ℹ️ Whitelist masih kosong.' });
  }

  const lines: string[] = [];
  for (let i = 0; i < entries.length; i++) {
    const e = entries[i]!;
    const [{ value: keyCount }] = await db
      .select({ value: count() })
      .from(licenseOwners)
      .where(eq(licenseOwners.discordUserId, e.discordUserId));
    const vipStatus = e.claimedVip ? '✅' : '❌';
    lines.push(`**${i + 1}.** <@${e.discordUserId}> — ${keyCount} key — VIP: ${vipStatus}`);
  }

  const embed = new EmbedBuilder()
    .setColor(0x9b59b6)
    .setTitle(`🎖️ Whitelist VIP (${entries.length} member)`)
    .setDescription(lines.join('\n'))
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
