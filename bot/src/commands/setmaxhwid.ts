import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey } from '../utils/keys.js';
import { hwidPeriodLabel } from '../utils/time.js';

export const SETMAXHWID_DEF = new SlashCommandBuilder()
  .setName('setmaxhwid')
  .setDescription('Atur batas & cooldown reset HWID untuk key tertentu')
  .addStringOption((o) => o.setName('key').setDescription('License key').setRequired(true))
  .addIntegerOption((o) =>
    o.setName('max').setDescription('Jumlah reset maksimal (-1 = unlimited)').setRequired(true).setMinValue(-1).setMaxValue(999),
  )
  .addStringOption((o) =>
    o.setName('period').setDescription('Jeda antar reset (default: WEEKLY)')
      .addChoices(
        { name: 'DAILY', value: 'DAILY' },
        { name: 'WEEKLY', value: 'WEEKLY' },
        { name: 'MONTHLY', value: 'MONTHLY' },
        { name: 'UNLIMITED', value: 'UNLIMITED' },
      ),
  );

export async function setmaxhwid(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const max = interaction.options.getInteger('max', true);
  const period = (interaction.options.getString('period') ?? 'WEEKLY') as 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'UNLIMITED';

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });

  await db.update(licenses).set({ maxHwidResets: max, hwidPeriod: period }).where(eq(licenses.key, key));

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle('⚙️ Batas Reset HWID Diperbarui')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Maks Reset', value: max === -1 ? '∞ Unlimited' : `${max}x`, inline: true },
      { name: 'Periode', value: hwidPeriodLabel(period), inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
