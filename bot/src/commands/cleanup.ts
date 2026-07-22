import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { and, inArray, lt, sql } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';

export const CLEANUP_DEF = new SlashCommandBuilder()
  .setName('cleanup')
  .setDescription('Hapus key EXPIRED/REVOKED yang sudah melewati batas hari tertentu')
  .addIntegerOption((o) =>
    o.setName('days').setDescription('Hapus key lebih dari X hari (default: 30)').setMinValue(1).setMaxValue(365),
  );

export async function cleanup(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const days = interaction.options.getInteger('days') ?? 30;
  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const db = getDb();

  const toDelete = await db
    .select({ key: licenses.key })
    .from(licenses)
    .where(
      and(
        inArray(licenses.status, ['EXPIRED', 'REVOKED']),
        lt(licenses.createdAt, cutoff),
      ),
    );

  if (toDelete.length === 0) {
    return interaction.editReply({ content: `ℹ️ Tidak ada key untuk dibersihkan (batas: ${days} hari).` });
  }

  await db.delete(licenses).where(
    and(
      inArray(licenses.status, ['EXPIRED', 'REVOKED']),
      lt(licenses.createdAt, cutoff),
    ),
  );

  const embed = new EmbedBuilder()
    .setColor(0xf39c12)
    .setTitle('🧹 Database Dibersihkan')
    .addFields(
      { name: 'Key Dihapus', value: `${toDelete.length}`, inline: true },
      { name: 'Batas Hari', value: `${days} hari`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
