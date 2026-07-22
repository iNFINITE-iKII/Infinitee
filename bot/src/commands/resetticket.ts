import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { pendingTickets } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { discordTimestamp } from '../utils/time.js';

export const RESETTICKET_DEF = new SlashCommandBuilder()
  .setName('resetticket')
  .setDescription('Reset status tiket pending yang tersangkut milik seorang user')
  .addUserOption((o) => o.setName('user').setDescription('User Discord').setRequired(true));

export async function resetticket(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const user = interaction.options.getUser('user', true);

  const [ticket] = await db.select().from(pendingTickets).where(eq(pendingTickets.discordUserId, user.id));

  if (!ticket) {
    return interaction.editReply({ content: `ℹ️ <@${user.id}> tidak memiliki tiket yang tersangkut.` });
  }

  await db.delete(pendingTickets).where(eq(pendingTickets.discordUserId, user.id));

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('🔄 Tiket Berhasil Direset')
    .addFields(
      { name: 'User', value: `<@${user.id}> (${user.username})`, inline: true },
      { name: 'Channel Tiket Lama', value: ticket.channelId, inline: true },
      { name: 'Tiket Dibuat', value: discordTimestamp(ticket.createdAt), inline: true },
      { name: 'Direset oleh', value: `<@${interaction.user.id}>`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
