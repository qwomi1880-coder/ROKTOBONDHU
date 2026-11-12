-- ROKTOBONDHU: Supabase SQL Editor-এ পুরোটা একবারে Run করুন
create table divisions(id serial primary key,name text unique not null);
create table districts(id serial primary key,division_id int references divisions,name text not null);
create table upazilas(id serial primary key,district_id int references districts,name text not null);
insert into divisions(name) values ('ঢাকা'),('চট্টগ্রাম'),('রাজশাহী'),('খুলনা'),('বরিশাল'),('সিলেট'),('রংপুর'),('ময়মনসিংহ');
insert into districts(division_id,name)
select d.id,trim(n) from (values
('ঢাকা','ঢাকা,গাজীপুর,নারায়ণগঞ্জ,নরসিংদী,মানিকগঞ্জ,মুন্সীগঞ্জ,কিশোরগঞ্জ,টাঙ্গাইল,ফরিদপুর,মাদারীপুর,শরীয়তপুর,গোপালগঞ্জ,রাজবাড়ী'),
('চট্টগ্রাম','চট্টগ্রাম,কক্সবাজার,কুমিল্লা,ব্রাহ্মণবাড়িয়া,চাঁদপুর,ফেনী,নোয়াখালী,লক্ষ্মীপুর,খাগড়াছড়ি,রাঙ্গামাটি,বান্দরবান'),
('রাজশাহী','রাজশাহী,বগুড়া,জয়পুরহাট,নওগাঁ,নাটোর,চাঁপাইনবাবগঞ্জ,পাবনা,সিরাজগঞ্জ'),
('খুলনা','খুলনা,বাগেরহাট,সাতক্ষীরা,যশোর,নড়াইল,মাগুরা,ঝিনাইদহ,কুষ্টিয়া,চুয়াডাঙ্গা,মেহেরপুর'),
('বরিশাল','বরিশাল,বরগুনা,ভোলা,ঝালকাঠি,পটুয়াখালী,পিরোজপুর'),
('সিলেট','সিলেট,হবিগঞ্জ,মৌলভীবাজার,সুনামগঞ্জ'),
('রংপুর','রংপুর,দিনাজপুর,গাইবান্ধা,কুড়িগ্রাম,লালমনিরহাট,নীলফামারী,পঞ্চগড়,ঠাকুরগাঁও'),
('ময়মনসিংহ','ময়মনসিংহ,জামালপুর,নেত্রকোণা,শেরপুর')) v(dv,names)
join divisions d on d.name=v.dv, unnest(string_to_array(v.names,',')) n;
-- উপজেলা/থানা: Table Editor → upazilas → Import CSV (district_id,name)। ওপেন ডেটাসেট: "bangladesh-geocode" (GitHub)

create table profiles(id uuid primary key references auth.users on delete cascade,
 name text,phone text,blood text,district_id int references districts,upazila_id int references upazilas,
 area text,last_donated date,role text not null default 'user',
 kyc text not null default 'none' check(kyc in('none','pending','verified','rejected')),
 reports int not null default 0,created_at timestamptz default now());
create table requests(id bigserial primary key,user_id uuid references profiles default auth.uid(),patient text,blood text,bags int,
 hospital text,district_id int,upazila_id int,needed_at text,contact_phone text,note text,
 status text not null default 'open',created_at timestamptz default now());
create table reports(id bigserial primary key,target uuid,reporter uuid default auth.uid(),why text,unique(target,reporter));
create table contacts(id bigserial primary key,requester uuid,donor uuid,at timestamptz default now());
create table payment_methods(id serial primary key,name text,number text,instructions text,active bool default false,sort int default 0);
create table emergency_numbers(id serial primary key,label text,number text,active bool default true,sort int default 0);
create table donations(id bigserial primary key,user_id uuid default auth.uid(),name text,amount numeric,method text,trx_id text,
 status text not null default 'pending' check(status in('pending','confirmed','rejected')),created_at timestamptz default now());

insert into payment_methods(name,number,instructions,sort) values
('bKash','01XXXXXXXXX','Send Money করে TrxID দিন',1),('Nagad','01XXXXXXXXX','Send Money করে TrxID দিন',2),('Rocket','01XXXXXXXXX-X','Send Money করে TrxID দিন',3);
insert into emergency_numbers(label,number,sort) values('জাতীয় জরুরি সেবা','999',1),('ফায়ার সার্ভিস','16163',2),('স্বাস্থ্য বাতায়ন','16263',3),('নারী ও শিশু হেল্পলাইন','109',4);

create function is_admin() returns bool language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;

-- শুধু যাচাইকৃত, স্থগিত নয়, ৯০ দিন পার হয়েছে এমন ডোনার; ফোন নম্বর নেই
create view donors as select id,name,blood,district_id,upazila_id,area,last_donated from profiles
 where kyc='verified' and reports<3 and (last_donated is null or last_donated<=current_date-90);
create view fund_total as select coalesce(sum(amount),0) as total from donations where status='confirmed';
grant select on donors,fund_total to anon,authenticated;

create function get_phone(uid uuid) returns text language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from profiles where id=auth.uid() and kyc='verified') then raise exception 'verified_only'; end if;
 insert into contacts(requester,donor) values(auth.uid(),uid);
 return (select phone from profiles where id=uid and kyc='verified');
end $$;
create function report_user(uid uuid,w text) returns void language plpgsql security definer set search_path=public as $$
begin
 insert into reports(target,reporter,why) values(uid,auth.uid(),w);
 update profiles set reports=(select count(*) from reports where target=uid) where id=uid;
end $$;
create function submit_kyc() returns void language sql security definer set search_path=public as
$$ update profiles set kyc='pending' where id=auth.uid() and kyc in('none','rejected') $$;
create function admin_set_kyc(uid uuid,s text) returns void language plpgsql security definer set search_path=public as $$
begin if not is_admin() then raise exception 'admin_only'; end if; update profiles set kyc=s where id=uid; end $$;

alter table divisions enable row level security;alter table districts enable row level security;alter table upazilas enable row level security;
create policy g1 on divisions for select using(true);create policy g2 on districts for select using(true);create policy g3 on upazilas for select using(true);
alter table profiles enable row level security;
create policy p_sel on profiles for select to authenticated using(id=auth.uid() or is_admin());
create policy p_ins on profiles for insert to authenticated with check(id=auth.uid());
create policy p_upd on profiles for update to authenticated using(id=auth.uid());
revoke insert,update on profiles from authenticated,anon;
grant insert(id,name,phone,blood,district_id,upazila_id,area,last_donated),update(name,phone,blood,district_id,upazila_id,area,last_donated) on profiles to authenticated;
alter table requests enable row level security;
create policy r_sel on requests for select to authenticated using(status='open' or user_id=auth.uid() or is_admin());
create policy r_ins on requests for insert to authenticated with check(user_id=auth.uid());
create policy r_upd on requests for update to authenticated using(user_id=auth.uid() or is_admin());
create policy r_del on requests for delete to authenticated using(is_admin());
alter table reports enable row level security;create policy rp on reports for select to authenticated using(is_admin());
alter table contacts enable row level security;create policy c on contacts for select to authenticated using(is_admin());
alter table payment_methods enable row level security;
create policy pm1 on payment_methods for select using(active or is_admin());
create policy pm2 on payment_methods for all to authenticated using(is_admin()) with check(is_admin());
alter table emergency_numbers enable row level security;
create policy en1 on emergency_numbers for select using(active or is_admin());
create policy en2 on emergency_numbers for all to authenticated using(is_admin()) with check(is_admin());
alter table donations enable row level security;
create policy d1 on donations for insert to authenticated with check(user_id=auth.uid() and status='pending');
create policy d2 on donations for select to authenticated using(user_id=auth.uid() or is_admin());
create policy d3 on donations for update to authenticated using(is_admin());
create policy d4 on donations for delete to authenticated using(is_admin());

insert into storage.buckets(id,name,public) values('kyc','kyc',false) on conflict do nothing;
create policy k1 on storage.objects for insert to authenticated with check(bucket_id='kyc' and (storage.foldername(name))[1]=auth.uid()::text);
create policy k2 on storage.objects for update to authenticated using(bucket_id='kyc' and (storage.foldername(name))[1]=auth.uid()::text);
create policy k3 on storage.objects for select to authenticated using(bucket_id='kyc' and (is_admin() or (storage.foldername(name))[1]=auth.uid()::text));
create policy k4 on storage.objects for delete to authenticated using(bucket_id='kyc' and is_admin());

-- প্রথম অ্যাডমিন: নিজে সাইন-আপ করে তারপর এটা Run করুন (ইমেইল বদলান)
-- update profiles set role='admin',kyc='verified' where id=(select id from auth.users where email='you@example.com');
