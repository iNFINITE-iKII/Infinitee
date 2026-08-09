import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, licenseOwners } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';
import { getEffectiveStatus, statusEmoji } from '../utils/time.js';

export const DELETEKEY_DEF = new SlashCommandBuilder()
  .setName('deletekey')
  .setDescription('Hapus license key dari database sepenuhnya')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true));

export async function deletekey(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));

  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });

  const [owner] = await db.select().from(licenseOwners).where(eq(licenseOwners.licenseKey, key));
  const effectiveStatus = getEffectiveStatus(lic.status, lic.expiresAt);

  await db.delete(licenses).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0xe74c3c)
    .setTitle('🗑️ Key Dihapus Permanen')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Status (sebelum dihapus)', value: `${statusEmoji(effectiveStatus)} ${effectiveStatus}`, inline: true },
      { name: 'Pemilik (sebelum dihapus)', value: owner ? `<@${owner.discordUserId}>` : 'Tidak ada', inline: true },
      { name: 'Dihapus oleh', value: `<@${interaction.user.id}>`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
