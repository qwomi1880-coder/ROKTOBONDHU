#!/bin/bash
set -e
cd "$(git rev-parse --show-toplevel)"
read -rp "1) Project URL: " URL
read -rp "2) anon key: " KEY
read -rp "3) Session pooler URI (পাসওয়ার্ডসহ): " DB
read -rp "4) আপনার ইমেইল: " EMAIL
sed -i "s|YOUR_SUPABASE_URL|$URL|;s|YOUR_ANON_KEY|$KEY|" index.html
command -v psql >/dev/null || { sudo apt-get update -qq && sudo apt-get install -y -qq postgresql-client; }
echo "ডাটাবেস সেটআপ হচ্ছে..."
psql "$DB" -v ON_ERROR_STOP=1 -q -f schema.sql
(git add -A && git commit -qm "Supabase config" && git push -q) || true
(python3 -m http.server 3000 >/dev/null 2>&1 &)
echo ""
echo "এখন নিচে PORTS ট্যাবে 3000 পোর্টের লিংক খুলুন এবং এই ইমেইলে নতুন অ্যাকাউন্ট খুলুন: $EMAIL"
read -rp "অ্যাকাউন্ট খোলা হলে এখানে Enter চাপুন: " _
psql "$DB" -c "insert into profiles(id,name,role,kyc) select id,'Admin','admin','verified' from auth.users where email='$EMAIL' on conflict(id) do update set role='admin',kyc='verified'"
echo "হয়ে গেছে! অ্যাপ রিফ্রেশ করলে অ্যাডমিন ট্যাব দেখবেন।"
