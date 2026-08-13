class S {
  S(this.fa);
  final bool fa;

  String get appName => 'GuruProxy v2.2';
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
  String get blockedApps => fa ? 'مسدود کردن نرم‌افزارها از پروکسی' : 'Block apps from proxy';
  String get blockedAppsList => fa ? 'نام فایل‌ها (هر خط یکی)' : 'Exe names (one per line)';
  String get blockedAppsHint => fa
      ? 'با SOCKS/HTTP محلی نمی‌شود بر اساس process فیلتر کرد. لیست ذخیره می‌شود برای TUN بعدی. فعلاً فقط برنامه‌هایی که به پروکسی وصل نشوند از آن استفاده نمی‌کنند.'
      : 'Plain SOCKS/HTTP cannot filter by process name. This list is saved for future TUN routing. Today: apps only use the proxy if you point them at it.';
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
  String get tagline =>
      fa ? 'پروکسی CDN برای شبکه‌های فیلترشده' : 'CDN-fronted proxy for filtered networks';

  String get aboutBody => fa
      ? 'GuruProxy یک کلاینت مستقل برای تونل CDN-fronting است. رابط و برندینگ ماست؛ موتور تونل از پروژهٔ متن‌باز Psiphon استفاده می‌کند.\n\nبا سپاس از تیم Psiphon برای tunnel-core و اکوسیستم circumvention که این نرم‌افزار روی آن بنا شده است.'
      : 'GuruProxy is an independent CDN-fronting client. The UI and branding are ours; the tunnel engine uses the open-source Psiphon tunnel-core.\n\nThanks to the Psiphon team for tunnel-core and the circumvention ecosystem this app builds on.';

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
