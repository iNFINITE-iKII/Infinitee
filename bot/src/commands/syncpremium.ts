import { ChatInputCommandInteraction, EmbedBuilder, SlashCommandBuilder } from 'discord.js';
import { eq, inArray } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import { licenses, licenseOwners } from '../db/schema.js';
import { isAdmin, adminDeniedEmbed } from '../utils/admin.js';

export const SYNCPREMIUM_DEF = new SlashCommandBuilder()
  .setName('syncpremium')
  .setDescription('Cabut role PREMIUM dari member yang tidak lagi eligible');

export async function syncpremium(interaction: ChatInputCommandInteraction) {
  if (!isAdmin(interaction)) {
    return interaction.reply({ embeds: [adminDeniedEmbed()], ephemeral: true });
  }
  await interaction.deferReply({ ephemeral: true });

  if (!interaction.guild) return interaction.editReply({ content: '❌ Command ini hanya bisa di server.' });

  const db = getDb();
  const premiumRoleName = process.env.PREMIUM_ROLE_NAME ?? 'PREMIUM';
  const premiumRole = interaction.guild.roles.cache.find((r) => r.name === premiumRoleName);

  if (!premiumRole) {
    return interaction.editReply({ content: `❌ Role "${premiumRoleName}" tidak ditemukan di server.` });
  }

  await interaction.guild.members.fetch();
  const membersWithRole = premiumRole.members;

  // Get all users with ACTIVE PERMANENT key
  const eligibleOwners = await db
    .select({ discordUserId: licenseOwners.discordUserId })
    .from(licenseOwners)
    .innerJoin(licenses, eq(licenseOwners.licenseKey, licenses.key))
    .where(eq(licenses.type, 'PERMANENT'));

  const eligibleIds = new Set(eligibleOwners.map((e) => e.discordUserId));

  let kept = 0;
  let removed = 0;
  let failed = 0;

  for (const [memberId, member] of membersWithRole) {
    if (eligibleIds.has(memberId)) {
      kept++;
    } else {
      try {
        await member.roles.remove(premiumRole);
        removed++;
      } catch {
        failed++;
      }
    }
  }

  const embed = new EmbedBuilder()
    .setColor(0xf39c12)
    .setTitle('🔄 Sync Role PREMIUM Selesai')
    .addFields(
      { name: 'Total Diperiksa', value: `${membersWithRole.size}`, inline: true },
      { name: 'Dipertahankan', value: `${kept}`, inline: true },
      { name: 'Dicabut', value: `${removed}`, inline: true },
      { name: 'Gagal', value: `${failed}`, inline: true },
    )
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}
