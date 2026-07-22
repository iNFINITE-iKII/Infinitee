import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, licenseOwners } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';
import {
  getEffectiveStatus,
  statusEmoji,
  typeLabel,
  discordTimestamp,
  hwidPeriodLabel,
} from '../utils/time.js';

export const USERKEY_DEF = new SlashCommandBuilder()
  .setName('userkey')
  .setDescription('Lihat key milik user, atau cari pemilik key tertentu')
  .addUserOption((o) => o.setName('user').setDescription('User Discord (mode: lihat semua key user)'))
  .addStringOption((o) => o.setName('key').setDescription('License key (mode: cari pemilik key)'));

export async function userkey(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const user = interaction.options.getUser('user');
  const keyInput = interaction.options.getString('key');

  if (!user && !keyInput) {
    return interaction.editReply({ content: '❌ Isi minimal satu parameter: `user` atau `key`.' });
  }

  if (user) {
    // Mode: tampilkan semua key milik user
    const owned = await db
      .select()
      .from(licenseOwners)
      .where(eq(licenseOwners.discordUserId, user.id))
      .limit(10);

    if (owned.length === 0) {
      return interaction.editReply({ content: `ℹ️ <@${user.id}> tidak memiliki key.` });
    }

    const embed = new EmbedBuilder()
      .setColor(0x3498db)
      .setTitle(`🔑 Key Milik ${user.username}`)
      .setTimestamp();

    for (const o of owned) {
      const [lic] = await db.select().from(licenses).where(eq(licenses.key, o.licenseKey));
      if (!lic) continue;
      const eff = getEffectiveStatus(lic.status, lic.expiresAt);
      embed.addFields({
        name: `${statusEmoji(eff)} \`${lic.key}\``,
        value: [
          `Tipe: ${typeLabel(lic.type, lic.duration)}`,
          `Berlaku: ${lic.expiresAt ? discordTimestamp(lic.expiresAt) : '♾️ Permanent'}`,
          `Reset HWID: ${lic.userHwidResetCount}/${lic.maxHwidResets === -1 ? '∞' : lic.maxHwidResets} (${hwidPeriodLabel(lic.hwidPeriod)})`,
          lic.label ? `Label: ${lic.label}` : '',
        ]
          .filter(Boolean)
          .join('\n'),
        inline: false,
      });
    }

    return interaction.editReply({ embeds: [embed] });
  }

  // Mode: cari pemilik key
  const key = normalizeKey(keyInput!);
  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });

  const [owner] = await db.select().from(licenseOwners).where(eq(licenseOwners.licenseKey, key));
  const eff = getEffectiveStatus(lic.status, lic.expiresAt);

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle('🔍 Info Pemilik Key')
    .addFields(
      { name: 'Key', value: `\`${lic.key}\``, inline: false },
      { name: 'Status', value: `${statusEmoji(eff)} ${eff}`, inline: true },
      { name: 'Tipe', value: typeLabel(lic.type, lic.duration), inline: true },
      { name: 'Pemilik', value: owner ? `<@${owner.discordUserId}>` : 'Tidak ada', inline: true },
      { name: 'Dibuat oleh', value: `<@${lic.createdBy}>`, inline: true },
      {
        name: 'Berlaku Hingga',
        value: lic.expiresAt ? discordTimestamp(lic.expiresAt) : '♾️ Permanent',
        inline: true,
      },
      {
        name: 'Reset HWID',
        value: `${lic.userHwidResetCount}/${lic.maxHwidResets === -1 ? '∞' : lic.maxHwidResets} (${hwidPeriodLabel(lic.hwidPeriod)})`,
        inline: true,
      },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
