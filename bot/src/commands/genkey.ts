import {
  ChatInputCommandInteraction,
  EmbedBuilder,
  SlashCommandBuilder,
} from 'discord.js';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { generateKeys, generateId } from '../utils/keys.js';
import { calcExpiresAt, typeLabel } from '../utils/time.js';

export const GENKEY_DEF = new SlashCommandBuilder()
  .setName('genkey')
  .setDescription('Generate license key baru')
  .addStringOption((o) =>
    o.setName('type').setDescription('Tipe durasi').setRequired(true)
      .addChoices(
        { name: 'PERMANENT', value: 'PERMANENT' },
        { name: 'HOURLY', value: 'HOURLY' },
        { name: 'DAILY', value: 'DAILY' },
        { name: 'WEEKLY', value: 'WEEKLY' },
      ),
  )
  .addIntegerOption((o) =>
    o.setName('duration').setDescription('Durasi (wajib jika bukan PERMANENT)').setMinValue(1).setMaxValue(9999),
  )
  .addIntegerOption((o) =>
    o.setName('amount').setDescription('Jumlah key (default: 1, maks: 50)').setMinValue(1).setMaxValue(50),
  );

export async function genkey(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const type = interaction.options.getString('type', true) as 'PERMANENT' | 'HOURLY' | 'DAILY' | 'WEEKLY';
  const duration = interaction.options.getInteger('duration') ?? null;
  const amount = interaction.options.getInteger('amount') ?? 1;

  if (type !== 'PERMANENT' && !duration) {
    return interaction.editReply({ content: '❌ Parameter `duration` wajib diisi untuk tipe bukan PERMANENT.' });
  }

  const db = getDb();
  const keys = generateKeys(amount);
  const expiresAt = calcExpiresAt(type, duration);

  await db.insert(licenses).values(
    keys.map((key) => ({
      key,
      status: 'UNUSED' as const,
      type,
      duration,
      expiresAt,
      createdBy: interaction.user.id,
    })),
  );

  const keyList = keys.map((k) => `\`${k}\``).join('\n');
  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle(`✅ ${amount} Key Berhasil Di-generate`)
    .addFields(
      { name: 'Tipe', value: typeLabel(type, duration), inline: true },
      { name: 'Jumlah', value: `${amount}`, inline: true },
      { name: 'Keys', value: keyList.slice(0, 1024) },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
