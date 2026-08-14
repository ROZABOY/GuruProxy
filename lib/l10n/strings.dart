class S {
  S(this.fa);
  final bool fa;

  String get appName => 'GuruProxy v2.4.3';
  String get menuConnect => fa ? 'اتصال' : 'Connect';
  String get menuSession => fa ? 'نشست' : 'Session';
  String get menuWhiteIp => fa ? 'اسکنر IP' : 'White IP';
  String get menuSettings => fa ? 'تنظیمات' : 'Settings';
  String get menuLog => fa ? 'لاگ' : 'Log';
  String get menuHelp => fa ? 'راهنما' : 'Help';
  String get menuAbout => fa ? 'درباره' : 'About';
  String get menuTools => fa ? 'ابزار' : 'Tools';
  String get startConn => fa ? 'شروع اتصال' : 'Start';
  String get stopConn => fa ? 'قطع اتصال' : 'Stop';
  String get openConnect => fa ? 'صفحه اتصال' : 'Connect page';
  String get langToggle => fa ? 'EN' : 'FA';
  String get connect => fa ? 'وصل شو' : 'Connect';
  String get disconnect => fa ? 'قطع کن' : 'Disconnect';
  String get connecting => fa ? 'در حال اتصال…' : 'Connecting…';
  String get connected => fa ? 'متصل' : 'Connected';
  String get disconnected => fa ? 'قطع' : 'Disconnected';
  String get iranQuick => fa ? 'اتصال سریع ایران' : 'Iran Quick Connect';
  String get status => fa ? 'وضعیت' : 'Status';
  String get socks => fa ? 'SOCKS' : 'SOCKS';
  String get http => fa ? 'HTTP' : 'HTTP';
  String get protocols => fa ? 'پروتکل‌ها' : 'Protocols';
  String get autoProtocol => fa ? 'پروتکل خودکار (موبایل/دسکتاپ)' : 'Auto-protocol (mobile/desktop)';
  String get autoProtocolOn => fa ? 'خودکار (بهینه پلتفرم)' : 'Auto (platform-optimized)';
  String get autoProtocolHint => fa
      ? 'روشن: اندروید/iOS اولویت QUIC و Meek؛ ویندوز مجموعه CDN+OSSH سِون. خاموش: فقط چک‌باکس‌های زیر.'
      : 'On: Android/iOS prefer QUIC + Meek; Windows uses CDN + OSSH fronting. Off: only the checkboxes below.';
  String get protocolChecksHint => fa
      ? 'هر پروتکل را جدا روشن/خاموش کنید. روی موبایل معمولاً QUIC و Unfronted بهترند.'
      : 'Toggle each protocol. On phones, QUIC and Unfronted Meek often work better.';
  String get proxyListenMode => fa ? 'حالت پروکسی محلی' : 'Local proxy mode';
  String get proxyListenMixed => fa ? 'هر دو (SOCKS + HTTP)' : 'Mixed (SOCKS + HTTP)';
  String get proxyListenSocks => fa ? 'فقط SOCKS5' : 'SOCKS5 only';
  String get proxyListenHttp => fa ? 'فقط HTTP' : 'HTTP only';
  String get proxyListenHint => fa
      ? 'تونل یکی است؛ این فقط مشخص می‌کند کدام پورت محلی روشن باشد. پیش‌فرض: هر دو.'
      : 'One tunnel; this only chooses which local ports are on. Default: both.';
  String get connectionProfile => fa ? 'پروفایل اتصال' : 'Connection profile';
  String get connectionNormal => fa ? 'عادی (همین که کار می‌کند)' : 'Normal (working defaults)';
  String get connectionStable => fa ? 'پایدارتر (لینک‌های ضعیف)' : 'More stable (lossy links)';
  String get connectionProfileHint => fa
      ? 'BBR در Psiphon نیست. حالت پایدار فقط تایم‌اوت‌ها را نرم‌تر می‌کند — دیال‌ها را عوض نمی‌کند.'
      : 'Psiphon has no BBR. Stable only softens timeouts — dial overrides stay untouched.';
  String get redundantTunnel => fa ? 'تونل دوم (پایداری بیشتر)' : 'Second tunnel (extra stability)';
  String get redundantTunnelHint => fa
      ? 'TunnelPoolSize=2 — کمی سنگین‌تر، قطعی کمتر. فقط با پروفایل پایدار.'
      : 'TunnelPoolSize=2 — a bit heavier, fewer drops. Only with Stable profile.';
  String get nowDoing => fa ? 'الان چه می‌کند' : 'Now doing';
  String get nowDoingIdle => fa ? 'برای دیدن وضعیت کوتاه، وصل شوید.' : 'Connect to see a short live status.';
  String get region => fa ? 'منطقه' : 'Region';
  String get scanStart => fa ? 'شروع اسکن' : 'Start scan';
  String get scanStop => fa ? 'توقف' : 'Stop';
  String get scanPause => fa ? 'مکث' : 'Pause';
  String get scanResume => fa ? 'ادامه' : 'Resume';
  String get applyEdges => fa ? 'اعمال روی اتصال' : 'Apply to Connect';
  String get provider => fa ? 'ارائه‌دهنده CDN' : 'CDN provider';
  String get sni => fa ? 'SNI' : 'SNI';
  String get healthy => fa ? 'سالم' : 'Healthy';
  String get mode => fa ? 'حالت پروتکل' : 'Protocol mode';
  String get autoFind => fa ? 'یافتن خودکار IP و SNI' : 'Auto-find IP & SNI';
  String get autoFindHint => fa
      ? 'لبه‌های پیش‌فرض CDN را با لیست شما ادغام می‌کند.'
      : 'Merges built-in CDN edges with your custom list.';
  String get autoFindNow => fa ? 'اجرای یافتن خودکار' : 'Run auto-find now';
  String get sniOverride => fa ? 'بازنویسی SNI' : 'SNI override';
  String get sniOverrideHint => fa
      ? 'اگر خاموش باشد، SNIهای دستی در dial اعمال نمی‌شوند.'
      : 'When off, manual SNIs are not applied to dial overrides.';
  String get sniOverrideList => fa ? 'لیست SNI بازنویسی' : 'SNI override list';
  String get beastMode => fa ? 'حالت Beast' : 'Beast mode';
  String get beastModeHint => fa
      ? 'AggressiveEstablishment — اتصال تهاجمی‌تر، مصرف بیشتر.'
      : 'AggressiveEstablishment — more aggressive dialing, higher load.';
  String get upstreamProxy => fa ? 'پروکسی بالادستی' : 'Upstream proxy';
  String get upstreamUrl => fa ? 'آدرس پروکسی' : 'Proxy URL';
  String get upstreamUser => fa ? 'نام کاربری' : 'Username';
  String get upstreamPass => fa ? 'رمز' : 'Password';
  String get upstreamHint => fa
      ? 'فقط در حالت Direct/Auto استفاده می‌شود.'
      : 'Used only in Direct/Auto modes.';
  String get upstreamIgnoredCdn => fa
      ? 'در CDN Fronting نادیده گرفته می‌شود (جلوگیری از 10808 مرده).'
      : 'Ignored in CDN Fronting (avoids dead :10808 proxies).';
  String get blockedApps => fa ? 'Exclude apps (bypass proxy)' : 'Exclude apps (bypass proxy)';
  String get blockedAppsList => fa ? 'Exe names (one per line)' : 'Exe names (one per line)';
  String get blockedAppsHint => fa
      ? 'با SOCKS/HTTP محلی فیلتر process ممکن نیست. لیست ذخیره می‌شود. برنامه‌هایی که به پروکسی وصل نشوند از آن استفاده نمی‌کنند. برای فیلتر واقعی به TUN نیاز است.'
      : 'Plain SOCKS/HTTP cannot filter by process. List is saved. Apps only use the proxy if pointed at it. Real process bypass needs TUN.';
  String get copyLog => fa ? 'کپی لاگ' : 'Copy log';
  String get logCopied => fa ? 'لاگ کپی شد' : 'Log copied';
  String get sortBySpeed => fa ? 'مرتب‌سازی سرعت' : 'Sort by speed';
  String get recheckGroup => fa ? 'بررسی دوباره' : 'Recheck';
  String get expandGroup => fa ? 'جزئیات' : 'Details';
  String get customIps => fa ? 'IPهای سفارشی' : 'Custom IPs';
  String get customSnis => fa ? 'SNIهای سفارشی' : 'Custom SNIs';
  String get save => fa ? 'ذخیره' : 'Save';
  String get clearLog => fa ? 'پاک‌کردن لاگ' : 'Clear log';
  String get checkMethod => fa ? 'روش بررسی' : 'Check method';
  String get methodTls => fa ? 'TLS + SNI' : 'TLS + SNI';
  String get methodTcp => fa ? 'TCP 443' : 'TCP 443';
  String get methodPing => fa ? 'Ping (ICMP)' : 'Ping (ICMP)';
  String get manualIps => fa ? 'IP دستی' : 'Manual IPs';
  String get scanRanges => fa ? 'اسکن رنج CDN' : 'Also scan CDN ranges';
  String get keepDefaults => fa ? 'نگه‌داشتن پیش‌فرض‌ها' : 'Keep built-in defaults';
  String get maxCandidates => fa ? 'حداکثر' : 'Max';
  String get concurrency => fa ? 'همزمانی' : 'Workers';
  String get timeoutMs => fa ? 'مهلت ms' : 'Timeout ms';
  String get perCidr => fa ? 'در هر رنج' : 'Per CIDR';
  String get groups => fa ? 'گروه‌های ذخیره‌شده' : 'Saved groups';
  String get groupName => fa ? 'نام گروه (مثلاً home)' : 'Group name (e.g. home)';
  String get saveGroup => fa ? 'ذخیره گروه' : 'Save group';
  String get useGroup => fa ? 'استفاده' : 'Use';
  String get deleteGroup => fa ? 'حذف' : 'Delete';
  String get loadedGroup => fa ? 'گروه بارگذاری شد' : 'Loaded group';
  String get noGroups => fa ? 'هنوز گروهی نیست — اسکن کنید و ذخیره کنید.' : 'No groups yet — scan and save one.';
  String get socksPort => fa ? 'پورت SOCKS محلی' : 'Local SOCKS port';
  String get httpPort => fa ? 'پورت HTTP محلی' : 'Local HTTP port';
  String get timeoutSec => fa ? 'مهلت اتصال (ثانیه)' : 'Establish timeout (sec)';
  String get helpTitle => fa ? 'راهنمای GuruProxy' : 'GuruProxy Help';
  String get aboutTitle => fa ? 'درباره GuruProxy' : 'About GuruProxy';
  String get tagline => fa
      ? 'پروکسی CDN — نسخه موبایل‌محور v2.4'
      : 'CDN-fronted proxy — app-focused mobile build';

  String get aboutBody => fa
      ? 'GuruProxy یک کلاینت مستقل CDN-fronting است. رابط و برندینگ متعلق به GuruProxy است.\n\nبا سپاس از تیم Psiphon برای tunnel-core و اکوسیستم circumvention.'
      : 'GuruProxy is an independent CDN-fronting client. UI and branding belong to GuruProxy.\n\nThanks to the Psiphon team for tunnel-core and the circumvention ecosystem.';

  String get helpCdn => fa
      ? 'حالت CDN Fronting ترافیک را از لبه‌های CDN (مثل Akamai) عبور می‌دهد. پروکسی سیستم نادیده گرفته می‌شود. خطای 403 یعنی IP فقط TLS دارد ولی فرانت Psiphon نیست — Iran Quick یا گروه Akamai با Keep defaults را امتحان کنید.'
      : 'CDN Fronting uses CDN edges (e.g. Akamai). System proxy is ignored. Meek 403 means the IP is TLS-ok but not a Psiphon front — try Iran Quick or an Akamai group with Keep defaults.';

  String get helpScan => fa
      ? 'اسکنر White IP: Ping / TCP443 / TLS+SNI، IP دستی، رنج CDN، مکث، و گروه‌های ذخیره‌شده (home/office).'
      : 'White IP scanner: Ping / TCP443 / TLS+SNI, manual IPs, CDN ranges, pause, and saved groups (home/office).';

  String get helpIran => fa
      ? 'اتصال سریع ایران: CDN + US + لبه‌های پیش‌فرض Akamai؛ IPهای اسکن قبلی پاک می‌شوند تا 403های اشتباه کمتر شود.'
      : 'Iran Quick Connect: CDN + US + built-in Akamai edges; clears prior scan IPs to avoid bad 403 overrides.';
}
