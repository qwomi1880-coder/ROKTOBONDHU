-- ROKTOBONDHU v3: Supabase SQL Editor-এ পুরোটা একবারে Run করুন (v2.sql আগে চালানো থাকতে হবে)
-- ১) বিভাগ-জেলা-উপজেলা (ওপেন ডেটা) আমদানি
create extension if not exists http with schema extensions;
create or replace function _geo(u text) returns jsonb language plpgsql as $$
declare j jsonb; e jsonb;
begin
 select content::jsonb into j from extensions.http_get(u);
 for e in select * from jsonb_array_elements(j) loop
  if e->>'type'='table' then return e->'data'; end if;
 end loop;
 return j;
end $$;
do $$
declare b text:='https://raw.githubusercontent.com/nuhil/bangladesh-geocode/master/'; a jsonb; c jsonb; d jsonb;
begin
 a:=_geo(b||'divisions/divisions.json'); c:=_geo(b||'districts/districts.json'); d:=_geo(b||'upazilas/upazilas.json');
 if jsonb_array_length(a)<8 or jsonb_array_length(c)<64 or jsonb_array_length(d)<400 then raise exception 'geo data incomplete'; end if;
 update profiles set district_id=null,upazila_id=null; update requests set district_id=null,upazila_id=null;
 delete from upazilas; delete from districts; delete from divisions;
 insert into divisions(id,name) select (x->>'id')::int,x->>'bn_name' from jsonb_array_elements(a) x;
 insert into districts(id,division_id,name) select (x->>'id')::int,(x->>'division_id')::int,x->>'bn_name' from jsonb_array_elements(c) x;
 insert into upazilas(id,district_id,name) select (x->>'id')::int,(x->>'district_id')::int,x->>'bn_name' from jsonb_array_elements(d) x;
end $$;
drop function _geo(text);
select setval(pg_get_serial_sequence('divisions','id'),(select max(id) from divisions));
select setval(pg_get_serial_sequence('districts','id'),(select max(id) from districts));
select setval(pg_get_serial_sequence('upazilas','id'),(select max(id) from upazilas));
-- ঢাকা ও চট্টগ্রাম মহানগরের থানা
insert into upazilas(district_id,name) select z.id,t from districts z,unnest(string_to_array('মিরপুর,উত্তরা,ধানমন্ডি,গুলশান,বনানী,মোহাম্মদপুর,তেজগাঁও,মতিঝিল,পল্টন,রমনা,শাহবাগ,লালবাগ,কোতোয়ালী,সূত্রাপুর,গেন্ডারিয়া,যাত্রাবাড়ী,ডেমরা,খিলগাঁও,বাড্ডা,রামপুরা,মুগদা,সবুজবাগ,হাজারীবাগ,কামরাঙ্গীরচর,কাফরুল,পল্লবী,শাহ আলী,দারুস সালাম,আদাবর,শ্যামপুর,কদমতলী,বংশাল,চকবাজার,নিউমার্কেট,কলাবাগান,তুরাগ,দক্ষিণখান,উত্তরখান,খিলক্ষেত,ভাটারা,শেরেবাংলা নগর,শাহজাহানপুর',',')) t where z.name='ঢাকা' and not exists(select 1 from upazilas u where u.district_id=z.id and u.name=t);
insert into upazilas(district_id,name) select z.id,t from districts z,unnest(string_to_array('কোতোয়ালী,পাহাড়তলী,পাঁচলাইশ,খুলশী,বন্দর,ডবলমুরিং,চান্দগাঁও,বায়েজিদ,হালিশহর,কর্ণফুলী,ইপিজেড,আকবর শাহ,বাকলিয়া,চকবাজার,সদরঘাট',',')) t where z.name='চট্টগ্রাম' and not exists(select 1 from upazilas u where u.district_id=z.id and u.name=t);

-- ২) যাচাই: এনআইডি বা জন্ম নিবন্ধন; রোগী/ডোনার
alter table profiles add column if not exists kyc_type text check(kyc_type in('nid','birth')),add column if not exists is_donor bool not null default true;
grant insert(is_donor),update(is_donor) on profiles to authenticated;
drop function if exists submit_kyc();
create or replace function submit_kyc(t text) returns void language plpgsql security definer set search_path=public as $$
begin
 if t not in('nid','birth') then raise exception 'bad_type'; end if;
 update profiles set kyc='pending',kyc_type=t where id=auth.uid() and kyc in('none','rejected');
end $$;

-- ৩) তথ্যের বৈধতা
alter table profiles drop constraint if exists ph_ck; alter table profiles add constraint ph_ck check((phone is null or phone ~ '^01[3-9][0-9]{8}$') and char_length(coalesce(name,''))<=80 and char_length(coalesce(area,''))<=120);
create unique index if not exists prof_phone on profiles(phone);
alter table requests drop constraint if exists rq_ck; alter table requests add constraint rq_ck check(contact_phone ~ '^01[3-9][0-9]{8}$' and bags between 1 and 50 and char_length(coalesce(note,''))<=500 and char_length(coalesce(hospital,''))<=150);

-- ৪) ডোনার তালিকা: শুধু লগইন করা ব্যবহারকারী, নম্বর মাস্ক করা
drop view if exists donors;
create view donors as select id,name,blood,district_id,upazila_id,area,last_donated,
 case when hide_phone then null else left(phone,5)||'XXXXXX' end as phone_mask,
 (last_donated+90) as next_date,(last_donated is null or last_donated<=current_date-90) as ready
 from profiles where kyc='verified' and is_donor and reports<3;
create or replace function get_phone(uid uuid) returns text language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'লগইন করুন'; end if;
 if (select count(*) from contacts where requester=auth.uid() and at>now()-interval '1 day')>=30 then raise exception 'আজকের নম্বর দেখার সীমা (৩০টি) শেষ'; end if;
 insert into contacts(requester,donor) values(auth.uid(),uid);
 return (select phone from profiles where id=uid and kyc='verified' and is_donor and not hide_phone);
end $$;
create or replace function notify_donors() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into notifications(user_id,title,body,request_id)
 select id,'জরুরি রক্তের অনুরোধ: '||new.blood,coalesce(new.hospital,'')||' · '||coalesce(new.bags,1)||' ব্যাগ',new.id
 from profiles where kyc='verified' and is_donor and blood=new.blood and id<>new.user_id and reports<3
 and (new.district_id is null or district_id=new.district_id) and (last_donated is null or last_donated<=current_date-90);
 return new;
end $$;

-- ৫) অতিথি (লগইন ছাড়া) কিছুই দেখতে পারবে না, শুধু এলাকার তালিকা ছাড়া
revoke all on all tables in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
grant select on divisions,districts,upazilas,payment_methods,emergency_numbers,fund_total to anon;
revoke all on donors from public; grant select on donors to authenticated;
revoke execute on function get_phone(uuid),submit_kyc(text),notify_donors() from public,anon;
grant execute on function get_phone(uuid),submit_kyc(text) to authenticated;
