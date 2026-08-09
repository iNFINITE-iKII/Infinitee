import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';

export const HELP_DEF = new SlashCommandBuilder()
  .setName('help')
  .setDescription('Tampilkan daftar command bot');

export async function help(interaction: ChatInputCommandInteraction) {
  const embed = new EmbedBuilder()
    .setColor(0x9b59b6)
    .setTitle('📋 Daftar Command — Infinitee Bot')
    .addFields(
      {
        name: '🔑 Manajemen Key',
        value: [
          '`/genkey` — Generate key baru',
          '`/checkkey` — Cek detail key',
          '`/revoke` — Cabut key (status REVOKED)',
          '`/deletekey` — Hapus key dari DB',
          '`/renewkey` — Perpanjang / ubah tipe key',
          '`/setlabel` — Tambah/hapus label key',
          '`/cleanup` — Bersihkan key lama',
        ].join('\n'),
      },
      {
        name: '🖥️ HWID & Akun',
        value: [
          '`/sethwid` — Bind HWID ke key (admin)',
          '`/resethwid` — Reset HWID binding (admin)',
          '`/setmaxhwid` — Atur batas & cooldown reset HWID',
          '`/setaccountlimit` — Atur max akun Roblox per key',
        ].join('\n'),
      },
      {
        name: '🎖️ Whitelist VIP',
        value: [
          '`/whitelist add` — Tambah user ke whitelist + generate key',
          '`/whitelist remove` — Hapus user dari whitelist',
          '`/whitelist list` — Tampilkan semua member whitelist',
        ].join('\n'),
      },
      {
        name: '🔍 Informasi',
        value: [
          '`/userkey` — Key milik user / pemilik key',
          '`/stats` — Statistik global',
          '`/transferkey` — Pindah kepemilikan key',
        ].join('\n'),
      },
      {
        name: '🔄 Lainnya',
        value: [
          '`/syncpremium` — Cabut role PREMIUM yang tidak eligible',
          '`/panel` — Kirim panel VIP ke channel',
          '`/resetticket` — Reset tiket pending yang tersangkut',
          '`/help` — Tampilkan pesan ini',
        ].join('\n'),
      },
    )
    .setFooter({ text: 'Semua command admin-only kecuali /help' })
    .setTimestamp();

  await interaction.reply({ embeds: [embed], ephemeral: true });
}
