import {
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  ChatInputCommandInteraction,
  EmbedBuilder,
  SlashCommandBuilder,
} from 'discord.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';

export const PANEL_DEF = new SlashCommandBuilder()
  .setName('panel')
  .setDescription('Kirim panel VIP interaktif ke channel ini');

export async function panel(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }

  const embed = new EmbedBuilder()
    .setColor(0x9b59b6)
    .setTitle('✨ Infinitee — Panel VIP')
    .setDescription(
      '> Selamat datang di panel VIP!\n\n' +
      '**Baris pertama** dapat diakses oleh siapa saja.\n' +
      '**Baris kedua** khusus untuk member yang sudah terdaftar di whitelist VIP.',
    )
    .addFields(
      {
        name: '🎁 Get Trial Key',
        value: 'Klaim trial key gratis selama 6 jam. **1x per akun, seumur hidup.**',
        inline: true,
      },
      {
        name: '💎 Buy PREMIUM',
        value: 'Buka tiket untuk membeli akses PREMIUM/Lifetime.',
        inline: true,
      },
      {
        name: '📜 Get Script',
        value: 'Dapatkan script Lua untuk digunakan di executor.',
        inline: true,
      },
    )
    .setTimestamp()
    .setFooter({ text: 'Semua respons bersifat ephemeral (hanya terlihat olehmu)' });

  const row1 = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId('panel_trial').setLabel('🎁 Get Trial Key').setStyle(ButtonStyle.Success),
    new ButtonBuilder().setCustomId('panel_buy').setLabel('💎 Buy PREMIUM').setStyle(ButtonStyle.Primary),
    new ButtonBuilder().setCustomId('panel_script').setLabel('📜 Get Script').setStyle(ButtonStyle.Secondary),
  );

  const row2 = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId('panel_vip_role').setLabel('🎖️ Get Role VIP').setStyle(ButtonStyle.Primary),
    new ButtonBuilder().setCustomId('panel_get_key').setLabel('🔑 Get Key').setStyle(ButtonStyle.Secondary),
    new ButtonBuilder().setCustomId('panel_reset_hwid').setLabel('🔄 Reset HWID').setStyle(ButtonStyle.Danger),
    new ButtonBuilder().setCustomId('panel_cek_hwid').setLabel('🔍 Cek HWID').setStyle(ButtonStyle.Secondary),
  );

  await interaction.reply({ content: '✅ Panel dikirim.', ephemeral: true });
  await interaction.channel!.send({ embeds: [embed], components: [row1, row2] });
}
