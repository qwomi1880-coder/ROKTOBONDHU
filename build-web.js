// শুধু প্রকাশযোগ্য ফাইল www/ ফোল্ডারে কপি করে (SQL/স্ক্রিপ্ট সাইটে যাবে না)
const fs = require("fs"), path = require("path");
const files = ["index.html","config.js","admin.js","manifest.webmanifest","sw.js","_headers","icon-192.png","icon-512.png","icon-maskable-512.png","apple-touch-icon.png"];
fs.rmSync("www", { recursive: true, force: true });
fs.mkdirSync("www");
for (const f of files) {
  if (!fs.existsSync(f)) { console.error("ফাইল নেই: " + f); process.exit(1); }
  fs.copyFileSync(f, path.join("www", f));
}
console.log("www প্রস্তুত (" + files.length + " ফাইল)");
