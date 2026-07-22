import { CommandInteraction, PermissionFlagsBits, EmbedBuilder } from 'discord.js';

export function isAdmin(interaction: CommandInteraction): boolean {
  if (!interaction.memberPermissions) return false;
  return interaction.memberPermissions.has(PermissionFlagsBits.Administrator);
}

export function adminDeniedEmbed(): EmbedBuilder {
  return new EmbedBuilder()
    .setColor(0xe74c3c)
    .setTitle('❌ Akses Ditolak')
    .setDescription('Command ini hanya dapat digunakan oleh **Administrator**.');
}
