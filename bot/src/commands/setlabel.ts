import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';

export const SETLABEL_DEF = new SlashCommandBuilder()
  .setName('setlabel')
  .setDescription('Tambah atau hapus label pada license key')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true))
  .addStringOption((o) => o.setName('label').setDescription('Label baru (kosongkan untuk hapus label)').setMaxLength(100));

export async function setlabel(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const label = interaction.options.getString('label') ?? null;

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });

  await db.update(licenses).set({ label }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle(label ? '🏷️ Label Ditambahkan' : '🏷️ Label Dihapus')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Label', value: label ?? '(dihapus)', inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
