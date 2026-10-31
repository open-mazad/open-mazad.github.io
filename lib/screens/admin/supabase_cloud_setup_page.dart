part of '../../main.dart';

// ======================= 7. إعداد قاعدة البيانات السحابية (Supabase + الحفظ المحلي) =======================

class SupabaseCloudSetupPage extends StatefulWidget {
  final bool embedded;
  const SupabaseCloudSetupPage({super.key, this.embedded = false});

  @override
  State<SupabaseCloudSetupPage> createState() => _SupabaseCloudSetupPageState();
}

class _SupabaseCloudSetupPageState extends State<SupabaseCloudSetupPage> {
  late final TextEditingController urlCtrl;
  late final TextEditingController keyCtrl;

  static const String supabaseSqlScript = '''
-- ============================================================
-- قاعدة بيانات تطبيق مزايدة (muzaida) الكاملة لـ Supabase
-- ============================================================

-- 1. جدول المستخدمين (Profiles)
create table if not exists public.profiles (
  id uuid default gen_random_uuid() primary key,
  phone text unique not null,
  first_name text not null,
  second_name text not null,
  third_name text not null,
  governorate text not null,
  photo_url text,
  rating numeric default 5.0,
  is_banned boolean default false,
  created_at timestamp with time zone default now()
);
alter table public.profiles drop constraint if exists profiles_id_fkey;

-- 2. جدول المزادات والسلع (Auctions / Items)
create table if not exists public.items (
  id uuid default gen_random_uuid() primary key,
  seller_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text not null,
  category text not null,
  condition text not null,
  location text not null,
  delivery_method text default 'استلام باليد',
  attributes jsonb default '{}'::jsonb,
  images text[] default '{}',
  video_url text,
  start_price bigint not null,
  current_price bigint not null,
  highest_bidder_id uuid references public.profiles(id),
  start_time timestamp with time zone default now(),
  end_time timestamp with time zone not null,
  pin_code text,
  is_ended_early boolean default false,
  is_cancelled boolean default false,
  created_at timestamp with time zone default now()
);

-- 3. جدول المزايدات العلنية (Bids)
create table if not exists public.bids (
  id uuid default gen_random_uuid() primary key,
  item_id uuid references public.items(id) on delete cascade not null,
  bidder_id uuid references public.profiles(id) on delete cascade not null,
  amount bigint not null,
  is_auto boolean default false,
  created_at timestamp with time zone default now()
);

-- 4. جدول المزايدة التلقائية (Auto Bids)
create table if not exists public.auto_bids (
  item_id uuid references public.items(id) on delete cascade,
  bidder_id uuid references public.profiles(id) on delete cascade,
  max_limit bigint not null,
  primary key (item_id, bidder_id)
);

-- 5. جدول الدردشة والتعليقات الحية (Live Chat & Comments)
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  item_id uuid references public.items(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamp with time zone default now()
);

-- 6. جدول تقييمات المستخدمين والسمعة (User Reviews)
create table if not exists public.reviews (
  id uuid default gen_random_uuid() primary key,
  target_user_id uuid references public.profiles(id) on delete cascade not null,
  reviewer_id uuid references public.profiles(id) on delete cascade not null,
  stars int not null check (stars >= 1 and stars <= 5),
  comment text not null,
  created_at timestamp with time zone default now()
);

-- 7. جدول البلاغات وحماية الجدية (Fraud Reports)
create table if not exists public.reports (
  id uuid default gen_random_uuid() primary key,
  reporter_id uuid references public.profiles(id) on delete cascade not null,
  reported_user_id uuid references public.profiles(id) on delete cascade not null,
  item_id uuid references public.items(id) on delete set null,
  item_title text not null,
  reason text not null,
  is_resolved boolean default false,
  created_at timestamp with time zone default now()
);

-- 8. جداول نظام المحادثات الاحترافي المنفصل (Conversations & Direct Messages)
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  last_message_at timestamptz default now(),
  last_message_preview text,
  created_at timestamptz default now(),
  unique (item_id, buyer_id)
);

create table if not exists public.conversation_members (
  conversation_id uuid references public.conversations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  last_read_at timestamptz default 'epoch',
  primary key (conversation_id, user_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  client_msg_id uuid not null unique,
  body text not null check (length(body) between 1 and 4000),
  type text not null default 'text',
  created_at timestamptz not null default now()
);
create index if not exists idx_direct_messages_conv_time
  on public.direct_messages (conversation_id, created_at desc);

-- ============================================================
-- تفعيل الحماية (RLS) مع سياسات القراءة والكتابة والخصوصية
-- ============================================================
alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.bids enable row level security;
alter table public.auto_bids enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;
alter table public.reports enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.direct_messages enable row level security;

drop policy if exists "public_all_profiles" on public.profiles;
create policy "public_all_profiles" on public.profiles for all using (true) with check (true);

drop policy if exists "public_all_items" on public.items;
create policy "public_all_items" on public.items for all using (true) with check (true);

drop policy if exists "public_all_bids" on public.bids;
create policy "public_all_bids" on public.bids for all using (true) with check (true);

drop policy if exists "public_all_auto_bids" on public.auto_bids;
create policy "public_all_auto_bids" on public.auto_bids for all using (true) with check (true);

-- سياسة جدول messages: التعليقات العامة متاحة للجميع، والرسائل الخاصة مقصورة على طرفي المحادثة عند توفر جلسة مصادقة
drop policy if exists "public_all_messages" on public.messages;
create policy "public_all_messages" on public.messages for select using (
  receiver_id is null
  or auth.uid() is null
  or sender_id = auth.uid()
  or receiver_id = auth.uid()
);
drop policy if exists "insert_messages" on public.messages;
create policy "insert_messages" on public.messages for insert with check (
  auth.uid() is null or sender_id = auth.uid()
);
drop policy if exists "delete_own_messages" on public.messages;
create policy "delete_own_messages" on public.messages for delete using (
  auth.uid() is null or sender_id = auth.uid()
);

drop policy if exists "read_own_conversations" on public.conversations;
create policy "read_own_conversations" on public.conversations for all using (
  auth.uid() is null or buyer_id = auth.uid() or seller_id = auth.uid()
) with check (
  auth.uid() is null or buyer_id = auth.uid() or seller_id = auth.uid()
);

drop policy if exists "members_access" on public.conversation_members;
create policy "members_access" on public.conversation_members for all using (
  auth.uid() is null or user_id = auth.uid()
) with check (
  auth.uid() is null or user_id = auth.uid()
);

drop policy if exists "read_own_direct_messages" on public.direct_messages;
create policy "read_own_direct_messages" on public.direct_messages for select using (
  auth.uid() is null or exists (
    select 1 from public.conversation_members m
    where m.conversation_id = direct_messages.conversation_id
      and m.user_id = auth.uid()
  )
);

drop policy if exists "send_own_direct_messages" on public.direct_messages;
create policy "send_own_direct_messages" on public.direct_messages for insert with check (
  auth.uid() is null or (
    sender_id = auth.uid() and exists (
      select 1 from public.conversation_members m
      where m.conversation_id = direct_messages.conversation_id
        and m.user_id = auth.uid()
    )
  )
);

drop policy if exists "public_all_reviews" on public.reviews;
create policy "public_all_reviews" on public.reviews for all using (true) with check (true);

drop policy if exists "public_all_reports" on public.reports;
create policy "public_all_reports" on public.reports for all using (true) with check (true);

-- ============================================================
-- تفعيل البث المباشر اللحظي (Supabase Realtime)
-- ============================================================
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.items;
alter publication supabase_realtime add table public.bids;
alter publication supabase_realtime add table public.auto_bids;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.reviews;
alter publication supabase_realtime add table public.reports;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_members;
alter publication supabase_realtime add table public.direct_messages;

alter table public.profiles replica identity full;
alter table public.items replica identity full;
alter table public.bids replica identity full;
alter table public.auto_bids replica identity full;
alter table public.messages replica identity full;
alter table public.reviews replica identity full;
alter table public.reports replica identity full;
alter table public.conversations replica identity full;
alter table public.conversation_members replica identity full;
alter table public.direct_messages replica identity full;
''';

  @override
  void initState() {
    super.initState();
    urlCtrl = TextEditingController(text: settings.supabaseUrl);
    keyCtrl = TextEditingController(text: settings.supabaseAnonKey);
  }

  @override
  void dispose() {
    urlCtrl.dispose();
    keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndSync() async {
    settings.saveSupabaseConfig(urlCtrl.text, keyCtrl.text);
    if (!settings.isCloudConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'تم إيقاف المزامنة السحابية والاكتفاء بالحفظ المحلي التلقائي 💾',
          'Cloud sync cleared; local persistence remains active 💾',
        )),
      ));
      return;
    }
    final err = await store.pushToSupabase();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: err == null ? Colors.green.shade700 : Colors.red.shade700,
      content: Text(err ??
          tr('تم الاتصال بـ Supabase ورفع جميع المزادات بنجاح! ☁️✅',
              'Connected to Supabase & pushed all auctions! ☁️✅')),
    ));
  }

  Future<void> _pullNow() async {
    settings.saveSupabaseConfig(urlCtrl.text, keyCtrl.text);
    final err = await store.pullFromSupabase();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: err == null ? Colors.green.shade700 : Colors.red.shade700,
      content: Text(err ??
          tr('تم جلب أحدث المزادات من سحابة Supabase بنجاح! ⬇️✅',
              'Pulled latest auctions from Supabase cloud! ⬇️✅')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: Listenable.merge([store, settings]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة الحفظ المحلي التلقائي
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('1. الحفظ المحلي التلقائي (مفعّل الآن 100%)',
                                '1. Automatic Local Disk Save (Active 100%)'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'جميع المزادات، المزايدات، الحساب، المفضلة، والتعليقات تُحفظ فوراً في ملف (muzaida_store.json) و(muzaida_settings.json) داخل مجلد المشروع، ولن تضيع عند إغلاق البرنامج أبداً.',
                        'All auctions, bids, account info, favorites, and comments are saved automatically to muzaida_store.json and persist across restarts.',
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Chip(
                          avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                          label: Text(tr(
                              'المزادات المحفوظة: ${store.items.length}',
                              'Saved Auctions: ${store.items.length}')),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            store.resetToDemoData();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(tr(
                                  'تمت استعادة البيانات الافتراضية وحفظها ✅',
                                  'Demo data restored & saved ✅')),
                            ));
                          },
                          icon: const Icon(Icons.restore, size: 18),
                          label: Text(tr('استعادة البيانات التجريبية',
                              'Reset Demo Data')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // خطوات إعداد Supabase
              Text(
                tr('2. ربط قاعدة بيانات سحابية حقيقية (Supabase مجاناً)',
                    '2. Connect Real Cloud Database (Free Supabase)'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'لمشاركة المزادات والمزايدات الحية بين عدة أجهزة ومستخدمين عبر الإنترنت:\n'
                  '• الخطوة 1: افتح موقع supabase.com وأنشئ مشروعاً مجانياً (New Project).\n'
                  '• الخطوة 2: افتح قسم (SQL Editor) في لوحة Supabase والصق الكود التالي ثم اضغط Run:',
                  'To sync live auctions across multiple devices over the internet:\n'
                  '• Step 1: Create a free project at supabase.com.\n'
                  '• Step 2: Open SQL Editor in Supabase, paste the SQL below, and click Run:',
                ),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SQL Schema (profiles, items, bids, auto_bids, messages)',
                          style: TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                const ClipboardData(text: supabaseSqlScript));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(tr('تم نسخ كود SQL للحافظة 📋',
                                  'SQL copied to clipboard 📋')),
                            ));
                          },
                          icon: const Icon(Icons.copy,
                              size: 16, color: Colors.white),
                          label: Text(tr('نسخ SQL', 'Copy SQL'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    SelectableText(
                      supabaseSqlScript.trim(),
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'Consolas',
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                tr(
                  '• الخطوة 3: من إعدادات مشروعك في Supabase (Project Settings -> API) انسخ الرابط والمفتاح العام والصقهما هنا:',
                  '• Step 3: From Supabase (Project Settings -> API), copy your Project URL & anon public key:',
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supabase Project URL',
                  hintText: 'https://xxxxxxxxxxxx.supabase.co',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supabase Anon Public Key',
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              if (store.lastSyncStatus != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.lastSyncStatus!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: store.isSyncingCloud ? null : _saveAndSync,
                      icon: store.isSyncingCloud
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(tr('حفظ ورفع للسحابة ☁️',
                          'Save & Push to Cloud ☁️')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: store.isSyncingCloud ? null : _pullNow,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(
                          tr('جلب من السحابة ⬇️', 'Pull from Cloud ⬇️')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('البيانات الحقيقية والسحابة (Supabase)',
            'Real Data & Supabase Cloud')),
      ),
      body: content,
    );
  }
}
