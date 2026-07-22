import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq, count } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, robloxAccounts } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';
import { sendLog, logEmbed } from '../utils/discord-logger.js';

export const RESETHWID_DEF = new SlashCommandBuilder()
  .setName('resethwid')
  .setDescription('Reset HWID binding key (admin, unlimited, tidak mempengaruhi counter user)')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true));

export async function resethwid(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));

  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });
  if (lic.status === 'REVOKED') return interaction.editReply({ content: `❌ Key REVOKED tidak bisa direset HWID-nya.` });

  const [{ value: boundCount }] = await db
    .select({ value: count() })
    .from(robloxAccounts)
    .where(eq(robloxAccounts.licenseKey, key));

  if (!lic.hwid && boundCount === 0) {
    return interaction.editReply({ content: `ℹ️ Key belum memiliki HWID binding.` });
  }

  // Hapus semua binding akun Roblox dan null-kan hwid di licenses
  await db.delete(robloxAccounts).where(eq(robloxAccounts.licenseKey, key));
  await db.update(licenses).set({ hwid: null }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle('🔓 HWID Berhasil Direset (Admin)')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Akun Dihapus', value: `${boundCount} akun`, inline: true },
      { name: 'Reset oleh', value: `<@${interaction.user.id}>`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
  await sendLog(logEmbed('🔓 Admin Reset HWID', 0x3498db).addFields(
    { name: 'Key', value: `\`${key}\``, inline: true },
    { name: 'Oleh', value: `<@${interaction.user.id}>`, inline: true },
  ));
}
