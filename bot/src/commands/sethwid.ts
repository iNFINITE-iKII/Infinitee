import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';

export const SETHWID_DEF = new SlashCommandBuilder()
  .setName('sethwid')
  .setDescription('Ikat (bind) license key ke HWID tertentu secara manual')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true))
  .addStringOption((o) => o.setName('hwid').setDescription('Hash HWID device tujuan').setRequired(true));

export async function sethwid(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const hwid = interaction.options.getString('hwid', true).trim();

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });
  if (lic.status === 'REVOKED') return interaction.editReply({ content: `❌ Key REVOKED tidak bisa di-bind HWID.` });

  await db.update(licenses).set({ hwid }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('🖥️ HWID Berhasil Di-set')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'HWID Baru', value: `\`${hwid.slice(0, 20)}...\``, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
