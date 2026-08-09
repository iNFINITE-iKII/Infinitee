import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq, count } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, robloxAccounts } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';

export const SETACCOUNTLIMIT_DEF = new SlashCommandBuilder()
  .setName('setaccountlimit')
  .setDescription('Atur jumlah maksimal akun Roblox yang bisa menggunakan satu key')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true))
  .addIntegerOption((o) =>
    o.setName('count').setDescription('Jumlah akun maksimal (1–1000)').setRequired(true).setMinValue(1).setMaxValue(1000),
  );

export async function setaccountlimit(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const limit = interaction.options.getInteger('count', true);

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });

  const [{ value: boundCount }] = await db
    .select({ value: count() })
    .from(robloxAccounts)
    .where(eq(robloxAccounts.licenseKey, key));

  await db.update(licenses).set({ accountLimit: limit }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle('👥 Account Limit Diperbarui')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Limit Baru', value: `${limit} akun`, inline: true },
      { name: 'Akun Terikat Saat Ini', value: `${boundCount}`, inline: true },
    );

  if (boundCount > limit) {
    embed.addFields({
      name: '⚠️ Peringatan',
      value: 'Limit baru lebih kecil dari jumlah akun yang sudah terikat. Gunakan `/resethwid` untuk membersihkan binding lama.',
    });
  }

  embed.setTimestamp();
  await interaction.editReply({ embeds: [embed] });
}
