import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { count, eq, inArray, sql } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, whitelist } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';

export const STATS_DEF = new SlashCommandBuilder()
  .setName('stats')
  .setDescription('Statistik global sistem license dan whitelist VIP');

export async function stats(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();

  const [totalKeys] = await db.select({ value: count() }).from(licenses);
  const [activeKeys] = await db.select({ value: count() }).from(licenses).where(eq(licenses.status, 'ACTIVE'));
  const [unusedKeys] = await db.select({ value: count() }).from(licenses).where(eq(licenses.status, 'UNUSED'));
  const [expiredKeys] = await db.select({ value: count() }).from(licenses).where(eq(licenses.status, 'EXPIRED'));
  const [revokedKeys] = await db.select({ value: count() }).from(licenses).where(eq(licenses.status, 'REVOKED'));
  const [totalWl] = await db.select({ value: count() }).from(whitelist);
  const [claimedWl] = await db.select({ value: count() }).from(whitelist).where(eq(whitelist.claimedVip, true));

  const embed = new EmbedBuilder()
    .setColor(0x9b59b6)
    .setTitle('📊 Statistik Sistem')
    .addFields(
      { name: '🔑 License Keys', value: '\u200b', inline: false },
      { name: '🟢 ACTIVE', value: `${activeKeys!.value}`, inline: true },
      { name: '🔵 UNUSED', value: `${unusedKeys!.value}`, inline: true },
      { name: '🟠 EXPIRED', value: `${expiredKeys!.value}`, inline: true },
      { name: '🔴 REVOKED', value: `${revokedKeys!.value}`, inline: true },
      { name: '📦 TOTAL', value: `${totalKeys!.value}`, inline: true },
      { name: '\u200b', value: '\u200b', inline: false },
      { name: '🎖️ Whitelist VIP', value: '\u200b', inline: false },
      { name: 'Total Member', value: `${totalWl!.value}`, inline: true },
      { name: 'Sudah Klaim VIP', value: `${claimedWl!.value}`, inline: true },
      { name: 'Belum Klaim', value: `${totalWl!.value - claimedWl!.value}`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
