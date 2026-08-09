import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';
import { sendLog, logEmbed } from '../utils/discord-logger.js';

export const REVOKE_DEF = new SlashCommandBuilder()
  .setName('revoke')
  .setDescription('Cabut license key secara permanen (masih ada di DB, status REVOKED)')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true));

export async function revoke(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));

  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });
  if (lic.status === 'REVOKED') return interaction.editReply({ content: `❌ Key sudah berstatus REVOKED.` });

  await db.update(licenses).set({ status: 'REVOKED' }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0xe74c3c)
    .setTitle('🔴 Key Direvoke')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Admin', value: `<@${interaction.user.id}>`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
  await sendLog(logEmbed('🔴 Key Direvoke', 0xe74c3c).addFields(
    { name: 'Key', value: `\`${key}\``, inline: true },
    { name: 'Oleh', value: `<@${interaction.user.id}>`, inline: true },
  ));
}
