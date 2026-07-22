import {
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  EmbedBuilder,
  ModalSubmitInteraction,
  TextChannel,
} from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, licenseOwners, whitelist, pendingTickets } from '../db/schema.js';
import { generateKeys, generateId, normalizeKey } from '../utils/keys.js';
import { calcExpiresAt, discordTimestamp, getEffectiveStatus, hwidCooldownMs, typeLabel } from '../utils/time.js';
import { sendLog, logEmbed } from '../utils/discord-logger.js';

export async function handleModal(interaction: ModalSubmitInteraction) {
  const id = interaction.customId;

  if (id === 'modal_reset_hwid') return handleResetHwid(interaction);
  if (id.startsWith('modal_approve_')) return handleApprove(interaction, id.replace('modal_approve_', ''));
}

// ─── Reset HWID (user) ────────────────────────────────────────────────────────
async function handleResetHwid(interaction: ModalSubmitInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const userId = interaction.user.id;
  const rawKey = interaction.fields.getTextInputValue('hwid_key');
  const key = normalizeKey(rawKey);

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));

  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });
  if (lic.status === 'REVOKED') return interaction.editReply({ content: '❌ Key berstatus REVOKED tidak bisa direset HWID-nya.' });
  if (!lic.hwid) return interaction.editReply({ content: 'ℹ️ Key belum terikat ke HWID, tidak perlu direset.' });

  // Cek kepemilikan
  const [owner] = await db.select().from(licenseOwners)
    .where(eq(licenseOwners.licenseKey, key));

  if (!owner || owner.discordUserId !== userId) {
    return interaction.editReply({ content: '❌ Key ini bukan milikmu.' });
  }

  // Cek batas reset
  if (lic.maxHwidResets !== -1 && lic.userHwidResetCount >= lic.maxHwidResets) {
    return interaction.editReply({ content: `❌ Kamu sudah mencapai batas maksimal reset HWID (${lic.maxHwidResets}x).` });
  }

  // Cek cooldown
  if (lic.hwidPeriod !== 'UNLIMITED' && lic.lastHwidResetAt) {
    const cooldown = hwidCooldownMs(lic.hwidPeriod);
    const nextReset = new Date(lic.lastHwidResetAt.getTime() + cooldown);
    if (nextReset > new Date()) {
      return interaction.editReply({
        content: `⏳ Kamu belum bisa reset HWID. Reset berikutnya: ${discordTimestamp(nextReset)}`,
      });
    }
  }

  await db.update(licenses).set({
    hwid: null,
    userHwidResetCount: lic.userHwidResetCount + 1,
    lastHwidResetAt: new Date(),
  }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('🔓 HWID Berhasil Direset')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Sisa Reset', value: lic.maxHwidResets === -1 ? '∞' : `${lic.maxHwidResets - lic.userHwidResetCount - 1}`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
  await sendLog(logEmbed('🔓 User Reset HWID', 0x3498db).addFields(
    { name: 'User', value: `<@${userId}>`, inline: true },
    { name: 'Key', value: `\`${key}\``, inline: true },
  ));
}

// ─── Approve ticket ───────────────────────────────────────────────────────────
async function handleApprove(interaction: ModalSubmitInteraction, targetUserId: string) {
  await interaction.deferUpdate();
  const db = getDb();

  const giveKeyRaw = interaction.fields.getTextInputValue('give_key').trim().toLowerCase();
  const giveKey = giveKeyRaw === 'ya' || giveKeyRaw === 'yes' || giveKeyRaw === 'y';
  const keyTypeRaw = interaction.fields.getTextInputValue('key_type').trim().toUpperCase() as
    'PERMANENT' | 'DAILY' | 'WEEKLY' | 'HOURLY';
  const durationRaw = interaction.fields.getTextInputValue('key_duration')?.trim();
  const duration = durationRaw ? parseInt(durationRaw) || 1 : null;
  const amountRaw = interaction.fields.getTextInputValue('key_amount').trim();
  const amount = Math.min(parseInt(amountRaw) || 1, 10);

  const validTypes = ['PERMANENT', 'DAILY', 'WEEKLY', 'HOURLY'];
  const keyType = validTypes.includes(keyTypeRaw) ? keyTypeRaw : 'PERMANENT';

  // Upsert whitelist
  await db.insert(whitelist).values({ discordUserId: targetUserId }).onConflictDoNothing();

  const generatedKeys: string[] = [];

  if (giveKey) {
    const keys = generateKeys(amount);
    const expiresAt = calcExpiresAt(keyType, duration);

    await db.insert(licenses).values(
      keys.map((k) => ({
        key: k,
        type: keyType,
        duration,
        expiresAt,
        maxHwidResets: 1,
        hwidPeriod: 'WEEKLY' as const,
        createdBy: interaction.user.id,
      })),
    );

    await db.insert(licenseOwners).values(
      keys.map((k) => ({ id: generateId(), licenseKey: k, discordUserId: targetUserId })),
    );

    generatedKeys.push(...keys);
  }

  // Berikan role PREMIUM jika PERMANENT
  if (keyType === 'PERMANENT' && interaction.guild) {
    try {
      const member = await interaction.guild.members.fetch(targetUserId);
      const premiumRoleName = process.env.PREMIUM_ROLE_NAME ?? 'PREMIUM';
      const role = interaction.guild.roles.cache.find((r) => r.name === premiumRoleName);
      if (role) await member.roles.add(role);
      await db.update(whitelist).set({ claimedVip: true }).where(eq(whitelist.discordUserId, targetUserId));
    } catch {}
  }

  // Remove pending ticket
  await db.delete(pendingTickets).where(eq(pendingTickets.discordUserId, targetUserId));

  // DM ke user
  try {
    const user = await interaction.client.users.fetch(targetUserId);
    const dmEmbed = new EmbedBuilder()
      .setColor(0x2ecc71)
      .setTitle('✅ Pembelian PREMIUM Disetujui!')
      .setDescription(
        giveKey
          ? `Key kamu:\n${generatedKeys.map((k) => `\`${k}\``).join('\n')}`
          : 'Kamu sudah ditambahkan ke whitelist VIP. Gunakan tombol **🔑 Get Key** di panel untuk melihat keymu.',
      )
      .addFields({ name: 'Tipe', value: typeLabel(keyType, duration), inline: true })
      .setTimestamp();
    await user.send({ embeds: [dmEmbed] });
  } catch {}

  await sendLog(logEmbed('✅ Tiket Disetujui', 0x2ecc71).addFields(
    { name: 'User', value: `<@${targetUserId}>`, inline: true },
    { name: 'Oleh', value: `<@${interaction.user.id}>`, inline: true },
    { name: 'Key', value: giveKey ? `${amount}x ${typeLabel(keyType, duration)}` : 'Tidak diberikan', inline: true },
  ));

  const closeRow = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder()
      .setCustomId(`tkt_close_${interaction.channelId}`)
      .setLabel('🔒 Tutup Ticket')
      .setStyle(ButtonStyle.Secondary),
  );

  await interaction.editReply({
    content: `✅ Pembelian disetujui. User sudah di-DM. Key: ${giveKey ? generatedKeys.map((k) => `\`${k}\``).join(', ') : 'tidak diberikan'}`,
    components: [closeRow],
  });
}
