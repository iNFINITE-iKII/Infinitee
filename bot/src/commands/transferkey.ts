import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, licenseOwners } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';
import { normalizeKey, generateId } from '../utils/keys.js';

export const TRANSFERKEY_DEF = new SlashCommandBuilder()
  .setName('transferkey')
  .setDescription('Pindahkan kepemilikan license key ke user lain')
  .addStringOption((o) => o.setName('key').setDescription('License key yang akan dipindah').setRequired(true))
  .addUserOption((o) => o.setName('to').setDescription('User penerima').setRequired(true));

export async function transferkey(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  const db = getDb();
  const key = normalizeKey(interaction.options.getString('key', true));
  const toUser = interaction.options.getUser('to', true);

  const [lic] = await db.select().from(licenses).where(eq(licenses.key, key));
  if (!lic) return interaction.editReply({ content: `❌ Key \`${key}\` tidak ditemukan.` });

  const [existingOwner] = await db.select().from(licenseOwners).where(eq(licenseOwners.licenseKey, key));

  if (existingOwner) {
    await db.update(licenseOwners)
      .set({ discordUserId: toUser.id })
      .where(eq(licenseOwners.licenseKey, key));
  } else {
    await db.insert(licenseOwners).values({ id: generateId(), licenseKey: key, discordUserId: toUser.id });
  }

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('🔄 Kepemilikan Key Dipindahkan')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Dari', value: existingOwner ? `<@${existingOwner.discordUserId}>` : '(tidak ada)', inline: true },
      { name: 'Ke', value: `<@${toUser.id}>`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
