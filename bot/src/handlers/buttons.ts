import {
  ActionRowBuilder,
  ButtonBuilder,
  ButtonInteraction,
  ButtonStyle,
  CategoryChannel,
  ChannelType,
  EmbedBuilder,
  ModalBuilder,
  PermissionFlagsBits,
  TextChannel,
  TextInputBuilder,
  TextInputStyle,
} from 'discord.js';
import { eq } from 'drizzle-orm';
import { getDb } from '../db/index.js';
import {
  licenses,
  licenseOwners,
  whitelist,
  trialClaims,
  pendingTickets,
} from '../db/schema.js';
import { generateKey, generateId } from '../utils/keys.js';
import {
  calcExpiresAt,
  discordTimestamp,
  getEffectiveStatus,
  hwidCooldownMs,
  hwidPeriodLabel,
  statusEmoji,
  typeLabel,
} from '../utils/time.js';
import { sendLog, logEmbed } from '../utils/discord-logger.js';

export async function handleButton(interaction: ButtonInteraction) {
  const id = interaction.customId;

  if (id === 'panel_trial') return handleTrial(interaction);
  if (id === 'panel_buy') return handleBuy(interaction);
  if (id === 'panel_script') return handleScript(interaction);
  if (id === 'panel_vip_role') return handleVipRole(interaction);
  if (id === 'panel_get_key') return handleGetKey(interaction);
  if (id === 'panel_reset_hwid') return handleResetHwidModal(interaction);
  if (id === 'panel_cek_hwid') return handleCekHwid(interaction);

  // Ticket admin buttons
  if (id.startsWith('tkt_approve_')) return handleApproveModal(interaction, id.replace('tkt_approve_', ''));
  if (id.startsWith('tkt_reject_')) return handleReject(interaction, id.replace('tkt_reject_', ''));
  if (id.startsWith('tkt_close_')) return handleClose(interaction);
}

// ─── Get Trial Key ────────────────────────────────────────────────────────────
async function handleTrial(interaction: ButtonInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const userId = interaction.user.id;

  const [existing] = await db.select().from(trialClaims).where(eq(trialClaims.discordUserId, userId));

  if (existing) {
    const [lic] = await db.select().from(licenses).where(eq(licenses.key, existing.licenseKey));
    const eff = lic ? getEffectiveStatus(lic.status, lic.expiresAt) : 'EXPIRED';
    const embed = new EmbedBuilder()
      .setColor(0xf39c12)
      .setTitle('⚠️ Trial Sudah Diklaim')
      .setDescription('Kamu sudah pernah klaim Trial Key sebelumnya.')
      .addFields(
        { name: 'Key Lama', value: `\`${existing.licenseKey}\``, inline: true },
        { name: 'Status', value: `${statusEmoji(eff)} ${eff}`, inline: true },
      )
      .setFooter({ text: 'Untuk akses PREMIUM, klik tombol 💎 Buy PREMIUM' });
    return interaction.editReply({ embeds: [embed] });
  }

  const key = generateKey();
  const expiresAt = calcExpiresAt('HOURLY', 6);

  await db.insert(licenses).values({
    key,
    status: 'UNUSED',
    type: 'HOURLY',
    duration: 6,
    expiresAt,
    maxHwidResets: 0,
    hwidPeriod: 'UNLIMITED',
    createdBy: 'SYSTEM',
  });

  await db.insert(licenseOwners).values({ id: generateId(), licenseKey: key, discordUserId: userId });
  await db.insert(trialClaims).values({ discordUserId: userId, licenseKey: key });

  const embed = new EmbedBuilder()
    .setColor(0x2ecc71)
    .setTitle('🎁 Trial Key Berhasil Diklaim!')
    .addFields(
      { name: 'Key', value: `\`${key}\``, inline: false },
      { name: 'Durasi', value: '6 Jam (timer mulai saat pertama diaktifkan)', inline: true },
      { name: 'Berlaku Hingga', value: discordTimestamp(expiresAt!), inline: true },
    )
    .addFields({
      name: '⚠️ Perhatian',
      value: '• Key terikat ke **1 perangkat** saja\n• **Tidak dapat direset** HWID\n• Hanya bisa klaim **1x seumur hidup**',
    })
    .setTimestamp();

  await interaction.editReply({ embeds: [embed] });
}

// ─── Buy PREMIUM (buka tiket) ─────────────────────────────────────────────────
async function handleBuy(interaction: ButtonInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const userId = interaction.user.id;

  // Cek whitelist
  const [wl] = await db.select().from(whitelist).where(eq(whitelist.discordUserId, userId));
  if (wl) {
    return interaction.editReply({
      content: '✅ Kamu sudah terdaftar di whitelist VIP! Gunakan tombol **🔑 Get Key** untuk melihat key kamu.',
    });
  }

  // Cek tiket pending
  const [pending] = await db.select().from(pendingTickets).where(eq(pendingTickets.discordUserId, userId));
  if (pending) {
    return interaction.editReply({
      content: `⚠️ Kamu sudah memiliki tiket yang sedang diproses: <#${pending.channelId}>. Tunggu response admin.`,
    });
  }

  if (!interaction.guild) return interaction.editReply({ content: '❌ Error: guild tidak ditemukan.' });

  // Buat channel tiket
  let category = interaction.guild.channels.cache.find(
    (c) => c.type === ChannelType.GuildCategory && c.name === 'Tickets',
  ) as CategoryChannel | undefined;

  if (!category) {
    category = (await interaction.guild.channels.create({
      name: 'Tickets',
      type: ChannelType.GuildCategory,
    })) as CategoryChannel;
  }

  const staffRoleId = process.env.TICKET_STAFF_ROLE_ID;
  const ticketChannel = await interaction.guild.channels.create({
    name: `ticket-${interaction.user.username}`,
    type: ChannelType.GuildText,
    parent: category.id,
    permissionOverwrites: [
      { id: interaction.guild.id, deny: [PermissionFlagsBits.ViewChannel] },
      { id: userId, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory] },
      { id: interaction.client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ManageChannels] },
      ...(staffRoleId ? [{ id: staffRoleId, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages] }] : []),
    ],
  }) as TextChannel;

  await db.insert(pendingTickets).values({ discordUserId: userId, channelId: ticketChannel.id });

  // Cek apakah user pernah klaim trial
  const [trial] = await db.select().from(trialClaims).where(eq(trialClaims.discordUserId, userId));

  const adminEmbed = new EmbedBuilder()
    .setColor(0x9b59b6)
    .setTitle('💎 Tiket Pembelian PREMIUM')
    .addFields(
      { name: 'User', value: `<@${userId}> (${interaction.user.username})`, inline: true },
      { name: 'User ID', value: userId, inline: true },
      { name: 'Status Trial', value: trial ? '✅ Sudah pernah klaim' : '❌ Belum pernah klaim', inline: true },
      { name: 'Waktu', value: discordTimestamp(new Date()), inline: true },
    )
    .setTimestamp();

  const adminRow = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId(`tkt_approve_${userId}`).setLabel('✅ Setujui & Beri Key').setStyle(ButtonStyle.Success),
    new ButtonBuilder().setCustomId(`tkt_reject_${userId}`).setLabel('❌ Tolak').setStyle(ButtonStyle.Danger),
    new ButtonBuilder().setCustomId(`tkt_close_${ticketChannel.id}`).setLabel('🔒 Tutup Ticket').setStyle(ButtonStyle.Secondary),
  );

  await ticketChannel.send({
    content: `<@${userId}> Tiket berhasil dibuat. Admin akan segera membantu kamu.`,
    embeds: [adminEmbed],
    components: [adminRow],
  });

  // Log ke ticket channel
  const logChannelId = process.env.TICKET_CHANNEL_ID;
  if (logChannelId) {
    try {
      const logChannel = await interaction.client.channels.fetch(logChannelId) as TextChannel;
      await logChannel.send({ embeds: [
        new EmbedBuilder().setColor(0x3498db).setTitle('🎫 Tiket Baru Masuk')
          .addFields(
            { name: 'User', value: `<@${userId}>`, inline: true },
            { name: 'Channel', value: `<#${ticketChannel.id}>`, inline: true },
          ).setTimestamp(),
      ] });
    } catch {}
  }

  // DM ke user
  try {
    await interaction.user.send(`✅ Tiket pembelian PREMIUM kamu sudah dibuat: <#${ticketChannel.id}>`);
  } catch {}

  await interaction.editReply({ content: `✅ Tiket berhasil dibuat! Silakan ke <#${ticketChannel.id}>.` });
}

// ─── Get Script ───────────────────────────────────────────────────────────────
async function handleScript(interaction: ButtonInteraction) {
  const loaderUrl = process.env.LOADER_URL ?? 'https://your-api.railway.app/api/lua/loader?game=soul_iron';
  const script = `loadstring(game:HttpGet("${loaderUrl}"))()`;

  const embed = new EmbedBuilder()
    .setColor(0x3498db)
    .setTitle('📜 Script Lua')
    .setDescription(`\`\`\`lua\n${script}\n\`\`\``)
    .setFooter({ text: '⚠️ Jangan bagikan script ini kepada siapapun!' })
    .setTimestamp();

  await interaction.reply({ embeds: [embed], ephemeral: true });
}

// ─── Get Role VIP ─────────────────────────────────────────────────────────────
async function handleVipRole(interaction: ButtonInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const userId = interaction.user.id;

  const [wl] = await db.select().from(whitelist).where(eq(whitelist.discordUserId, userId));
  if (!wl) {
    return interaction.editReply({ content: '❌ Kamu belum terdaftar di whitelist VIP.' });
  }

  // Cek key PERMANENT aktif
  const owned = await db.select({ licenseKey: licenseOwners.licenseKey })
    .from(licenseOwners).where(eq(licenseOwners.discordUserId, userId));

  let hasPermanent = false;
  for (const o of owned) {
    const [lic] = await db.select().from(licenses).where(eq(licenses.key, o.licenseKey));
    if (lic && lic.type === 'PERMANENT' && getEffectiveStatus(lic.status, lic.expiresAt) === 'ACTIVE') {
      hasPermanent = true;
      break;
    }
  }

  if (!hasPermanent) {
    return interaction.editReply({
      content: '❌ Kamu tidak memiliki key PERMANENT yang aktif. Key sementara (Daily/Weekly/Hourly) tidak memenuhi syarat untuk role VIP.',
    });
  }

  const premiumRoleName = process.env.PREMIUM_ROLE_NAME ?? 'PREMIUM';
  const role = interaction.guild?.roles.cache.find((r) => r.name === premiumRoleName);

  if (!role) {
    return interaction.editReply({ content: `❌ Role "${premiumRoleName}" tidak ditemukan di server.` });
  }

  const member = await interaction.guild!.members.fetch(userId);

  if (member.roles.cache.has(role.id)) {
    return interaction.editReply({ content: `✅ Role **${premiumRoleName}** sudah aktif di akunmu.` });
  }

  await member.roles.add(role);
  await db.update(whitelist).set({ claimedVip: true }).where(eq(whitelist.discordUserId, userId));

  await interaction.editReply({ content: `🎖️ Role **${premiumRoleName}** berhasil diberikan!` });
}

// ─── Get Key ──────────────────────────────────────────────────────────────────
async function handleGetKey(interaction: ButtonInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const userId = interaction.user.id;

  const [wl] = await db.select().from(whitelist).where(eq(whitelist.discordUserId, userId));
  if (!wl) return interaction.editReply({ content: '❌ Kamu belum terdaftar di whitelist VIP.' });

  const owned = await db.select({ licenseKey: licenseOwners.licenseKey })
    .from(licenseOwners).where(eq(licenseOwners.discordUserId, userId)).limit(10);

  if (owned.length === 0) return interaction.editReply({ content: 'ℹ️ Kamu belum memiliki key.' });

  const embed = new EmbedBuilder().setColor(0x9b59b6).setTitle('🔑 Key Milikmu').setTimestamp();

  for (const o of owned) {
    const [lic] = await db.select().from(licenses).where(eq(licenses.key, o.licenseKey));
    if (!lic) continue;
    const eff = getEffectiveStatus(lic.status, lic.expiresAt);
    embed.addFields({
      name: `${statusEmoji(eff)} \`${lic.key}\``,
      value: [
        `Tipe: **${typeLabel(lic.type, lic.duration)}**`,
        `Berlaku: ${lic.expiresAt ? discordTimestamp(lic.expiresAt) : '♾️ Permanent'}`,
        lic.label ? `Label: ${lic.label}` : '',
      ].filter(Boolean).join('\n'),
      inline: false,
    });
  }

  await interaction.editReply({ embeds: [embed] });
}

// ─── Reset HWID (buka modal) ──────────────────────────────────────────────────
async function handleResetHwidModal(interaction: ButtonInteraction) {
  const modal = new ModalBuilder().setCustomId('modal_reset_hwid').setTitle('🔄 Reset HWID');
  const input = new TextInputBuilder()
    .setCustomId('hwid_key')
    .setLabel('Masukkan license key kamu')
    .setStyle(TextInputStyle.Short)
    .setPlaceholder('XXXX-XXXX-XXXX-XXXX')
    .setRequired(true)
    .setMinLength(19)
    .setMaxLength(19);
  modal.addComponents(new ActionRowBuilder<TextInputBuilder>().addComponents(input));
  await interaction.showModal(modal);
}

// ─── Cek HWID ─────────────────────────────────────────────────────────────────
async function handleCekHwid(interaction: ButtonInteraction) {
  await interaction.deferReply({ ephemeral: true });
  const db = getDb();
  const userId = interaction.user.id;

  const [wl] = await db.select().from(whitelist).where(eq(whitelist.discordUserId, userId));
  if (!wl) return interaction.editReply({ content: '❌ Kamu belum terdaftar di whitelist VIP.' });

  const owned = await db.select({ licenseKey: licenseOwners.licenseKey })
    .from(licenseOwners).where(eq(licenseOwners.discordUserId, userId)).limit(10);

  if (owned.length === 0) return interaction.editReply({ content: 'ℹ️ Kamu belum memiliki key.' });

  const embed = new EmbedBuilder().setColor(0x3498db).setTitle('🔍 Status HWID Key Milikmu').setTimestamp();

  for (const o of owned) {
    const [lic] = await db.select().from(licenses).where(eq(licenses.key, o.licenseKey));
    if (!lic) continue;
    const eff = getEffectiveStatus(lic.status, lic.expiresAt);
    const maskedKey = `${lic.key.slice(0, 4)}-****-****-****`;
    embed.addFields({
      name: `${statusEmoji(eff)} \`${maskedKey}\``,
      value: [
        `HWID: ${lic.hwid ? `🔒 \`${lic.hwid.slice(0, 20)}...\`` : '🔓 Belum terikat'}`,
        `Cooldown Reset: **${hwidPeriodLabel(lic.hwidPeriod)}**`,
      ].join('\n'),
      inline: false,
    });
  }

  await interaction.editReply({ embeds: [embed] });
}

// ─── Approve (buka modal) ─────────────────────────────────────────────────────
async function handleApproveModal(interaction: ButtonInteraction, targetUserId: string) {
  const modal = new ModalBuilder()
    .setCustomId(`modal_approve_${targetUserId}`)
    .setTitle('✅ Setujui Pembelian PREMIUM');

  modal.addComponents(
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId('give_key').setLabel('Berikan Key? (ya/tidak)').setStyle(TextInputStyle.Short)
        .setPlaceholder('tidak').setValue('tidak').setRequired(true),
    ),
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId('key_type').setLabel('Tipe Key (PERMANENT/DAILY/WEEKLY/HOURLY)').setStyle(TextInputStyle.Short)
        .setPlaceholder('PERMANENT').setValue('PERMANENT').setRequired(true),
    ),
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId('key_duration').setLabel('Durasi (abaikan jika PERMANENT)').setStyle(TextInputStyle.Short)
        .setPlaceholder('1').setValue('1').setRequired(false),
    ),
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId('key_amount').setLabel('Jumlah Key (maks: 10)').setStyle(TextInputStyle.Short)
        .setPlaceholder('1').setValue('1').setRequired(true),
    ),
  );

  await interaction.showModal(modal);
}

// ─── Reject ───────────────────────────────────────────────────────────────────
async function handleReject(interaction: ButtonInteraction, targetUserId: string) {
  await interaction.deferUpdate();
  const db = getDb();

  await db.delete(pendingTickets).where(eq(pendingTickets.discordUserId, targetUserId));

  try {
    const user = await interaction.client.users.fetch(targetUserId);
    await user.send('❌ Permohonan pembelian PREMIUM kamu ditolak. Kamu bisa membuka tiket baru jika ingin mencoba lagi.');
  } catch {}

  await sendLog(logEmbed('❌ Tiket Ditolak', 0xe74c3c).addFields(
    { name: 'User', value: `<@${targetUserId}>`, inline: true },
    { name: 'Oleh', value: `<@${interaction.user.id}>`, inline: true },
  ));

  const closeRow = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId(`tkt_close_${interaction.channelId}`).setLabel('🔒 Tutup Ticket').setStyle(ButtonStyle.Secondary),
  );

  await interaction.editReply({ content: '❌ Tiket ditolak. User sudah di-DM.', components: [closeRow] });
}

// ─── Close ticket ─────────────────────────────────────────────────────────────
async function handleClose(interaction: ButtonInteraction) {
  const member = interaction.guild?.members.cache.get(interaction.user.id);
  if (!member?.permissions.has(PermissionFlagsBits.Administrator)) {
    return interaction.reply({ content: '❌ Hanya Administrator yang bisa menutup tiket.', ephemeral: true });
  }

  await interaction.deferUpdate();
  const channel = interaction.channel as TextChannel;

  await channel.send('🔒 Tiket akan ditutup dalam **5 detik**...');
  await new Promise((r) => setTimeout(r, 5000));

  // Remove pending ticket record if still exists
  const db = getDb();
  const tickets = await db.select().from(pendingTickets).where(eq(pendingTickets.channelId, channel.id));
  for (const t of tickets) {
    await db.delete(pendingTickets).where(eq(pendingTickets.discordUserId, t.discordUserId));
  }

  await channel.delete().catch(() => {});
}
