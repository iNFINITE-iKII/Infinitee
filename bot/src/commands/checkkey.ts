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

export const CHECKKEY_DEF = new SlashCommandBuilder()
  .setName('checkkey')
  .setDescription('Cek detail lengkap sebuah license key')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true));

export async function checkkey(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));

  if (!lic) {
    return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan di database.` });
  }

  const [owner] = await db.select().from(licenseOwners).where(eq(licenseOwners.licenseKey, key));
  const effectiveStatus = getEffectiveStatus(lic.status, lic.expiresAt);

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle('🔍 Detail License Key')
    .addFields(
      { name: 'Key', value: `\`${lic.key}\``, inline: false },
      { name: 'Status', value: `${statusEmoji(effectiveStatus)} ${effectiveStatus}`, inline: true },
      { name: 'Tipe', value: typeLabel(lic.type, lic.duration), inline: true },
      { name: 'HWID', value: lic.hwid ? `\`${lic.hwid.slice(0, 16)}...\`` : '🔓 Belum terikat', inline: true },
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
      { name: 'Pemilik', value: owner ? `<@${owner.discordUserId}>` : 'Tidak ada', inline: true },
      { name: 'Dibuat oleh', value: `<@${lic.createdBy}>`, inline: true },
      { name: 'Label', value: lic.label ?? '—', inline: true },
      { name: 'Dibuat pada', value: discordTimestamp(lic.createdAt), inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
