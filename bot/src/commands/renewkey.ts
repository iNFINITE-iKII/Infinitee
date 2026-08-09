import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';
import { calcExpiresAt, typeLabel, discordTimestamp } from '../utils/time.js';

export const RENEWKEY_DEF = new SlashCommandBuilder()
  .setName('renewkey')
  .setDescription('Perpanjang atau ubah tipe durasi license key')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true))
  .addStringOption((o) =>
    o.setName('type').setDescription('Tipe durasi baru').setRequired(true)
      .addChoices(
        { name: 'PERMANENT', value: 'PERMANENT' },
        { name: 'HOURLY', value: 'HOURLY' },
        { name: 'DAILY', value: 'DAILY' },
        { name: 'WEEKLY', value: 'WEEKLY' },
      ),
  )
  .addIntegerOption((o) =>
    o.setName('duration').setDescription('Durasi baru (wajib jika bukan PERMANENT)').setMinValue(1).setMaxValue(9999),
  );

export async function renewkey(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const type = interaction.options.getString('type', true) as 'PERMANENT' | 'HOURLY' | 'DAILY' | 'WEEKLY';
  const duration = interaction.options.getInteger('duration') ?? null;

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });
  if (lic.status === 'REVOKED') return interaction.editReply({ content: `❌ Key berstatus REVOKED tidak bisa diperpanjang.` });
  if (type !== 'PERMANENT' && !duration) {
    return interaction.editReply({ content: '❌ Parameter `duration` wajib untuk tipe bukan PERMANENT.' });
  }

  const expiresAt = calcExpiresAt(type, duration);
  const newStatus = lic.status === 'UNUSED' ? 'UNUSED' : 'ACTIVE';

  await db.update(licenses).set({ type, duration, expiresAt, status: newStatus }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('♻️ Key Berhasil Diperbarui')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Tipe Baru', value: typeLabel(type, duration), inline: true },
      { name: 'Berlaku Hingga', value: expiresAt ? discordTimestamp(expiresAt) : '♾️ Permanent', inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
