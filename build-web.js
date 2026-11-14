// শুধু প্রকাশযোগ্য ফাইল www/ ফোল্ডারে কপি করে (SQL/স্ক্রিপ্ট সাইটে যাবে না)
const fs = require("fs"), path = require("path");
const files = ["index.html","config.js","admin.js","manifest.webmanifest","sw.js","_headers","icon-192.png","icon-512.png","icon-maskable-512.png","apple-touch-icon.png","privacy.html"];
const build = Date.now().toString(36);
fs.rmSync("www", { recursive: true, force: true });
fs.mkdirSync("www");
for (const f of files) {
  if (!fs.existsSync(f)) { console.error("ফাইল নেই: " + f); process.exit(1); }
  if (f === "index.html") fs.writeFileSync(path.join("www", f), fs.readFileSync(f, "utf8").replace("__BUILD__", build));
  else fs.copyFileSync(f, path.join("www", f));
}
const sb = "node_modules/@supabase/supabase-js/dist/umd/supabase.js";
if (!fs.existsSync(sb)) { console.error("আগে npm install চালান (supabase.js পাওয়া যায়নি)"); process.exit(1); }
fs.copyFileSync(sb, "www/supabase.js");
fs.writeFileSync("www/version.json", JSON.stringify({ v: build }));
// config.js-এ site থাকলে অ্যাপ ওই সাইট থেকে সরাসরি লোড হবে (আপডেট নোটিফিকেশন কাজ করবে)
const m = fs.readFileSync("config.js", "utf8").match(/site\s*:\s*"([^"]+)"/);
if (m) {
  const c = JSON.parse(fs.readFileSync("capacitor.config.json", "utf8"));
  c.server = { ...c.server, url: m[1].replace(/\/$/, "") };
  fs.writeFileSync("capacitor.config.json", JSON.stringify(c, null, 2));
  console.log("সরাসরি মোড: " + m[1]);
} else console.log("অফলাইন-ফাইল মোড (config.js-এ site নেই)");
console.log("www প্রস্তুত, বিল্ড " + build);
