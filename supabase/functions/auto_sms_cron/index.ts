import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
import { initializeApp, cert } from 'npm:firebase-admin/app'
import { getMessaging } from 'npm:firebase-admin/messaging'

// 1. تهيئة الاتصال بفايربيس باستخدام المفتاح السري الذي رفعناه
const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
if (serviceAccountStr) {
  const serviceAccount = JSON.parse(serviceAccountStr);
  try {
    initializeApp({ credential: cert(serviceAccount) });
  } catch (e) {} // تجاهل إذا تم التهيئة مسبقاً
}

serve(async (req) => {
  try {
    // 2. الاتصال بقاعدة بيانات Supabase الخاصة بك
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Service Role لتخطي حماية RLS
    );

    // 🌟 3. السحر الزمني: تحويل توقيت سيرفرات أمريكا (UTC) إلى توقيت دمشق (UTC+3)
    const nowUtc = new Date();
    const damascusOffset = 3 * 60 * 60 * 1000; // 3 ساعات بالمللي ثانية
    // نضيف 3 ساعات للوقت الحالي لنحصل على وقت دمشق
    const damascusTime = new Date(nowUtc.getTime() + damascusOffset);

    // نستخدم getUTC لنستخرج اليوم والساعة والدقيقة بعد الإزاحة
    const currentDay = damascusTime.getUTCDate();
    const currentHour = damascusTime.getUTCHours();
    const currentMinute = damascusTime.getUTCMinutes();

    console.log(`جارٍ الفحص بتوقيت دمشق: يوم ${currentDay} - الساعة ${currentHour}:${currentMinute}`);

    // 🌟 4. البحث الدقيق عن الحملات المجدولة لليوم، ونفس الساعة، ونفس الدقيقة!
    const { data: schedules } = await supabase
      .from('schedules')
      .select('*')
      .eq('send_day', currentDay)
      .eq('send_hour', currentHour)
      .eq('send_minute', currentMinute)
      .eq('is_active', true);

    if (!schedules || schedules.length === 0) {
      return new Response(`لا توجد حملات لهذه الدقيقة (${currentHour}:${currentMinute}).`, { status: 200 });
    }

    // 5. جلب مفاتيح هواتف المستخدمين (FCM Tokens)
    const userIds = schedules.map(s => s.user_id);
    const { data: tokens } = await supabase
      .from('user_tokens')
      .select('*')
      .in('user_id', userIds);

    const tokenMap: Record<string, string> = {};
    tokens?.forEach(t => tokenMap[t.user_id] = t.fcm_token);

    let sentCount = 0;

    // 6. إرسال أوامر الاستيقاظ (Silent Push) للهواتف
    for (const schedule of schedules) {
      // التأكد من أنها لم تُرسل مسبقاً هذا الشهر
      let alreadySentThisMonth = false;
      if (schedule.last_sent_date) {
        const lastSent = new Date(schedule.last_sent_date);
        if (lastSent.getUTCMonth() === damascusTime.getUTCMonth() && lastSent.getUTCFullYear() === damascusTime.getUTCFullYear()) {
          alreadySentThisMonth = true;
        }
      }

      if (!alreadySentThisMonth) {
        const fcmToken = tokenMap[schedule.user_id];
        if (fcmToken) {
          // إرسال الإشارة الصامتة للهاتف
          await getMessaging().send({
            token: fcmToken,
            data: {
              group_id: schedule.group_id.toString(),
              message: schedule.message
            }
          });
          

          // تحديث تاريخ آخر إرسال في السحابة لمنع التكرار
          await supabase
            .from('schedules')
            .update({ last_sent_date: nowUtc.toISOString() }) // نحفظ الوقت الأصلي كمعيار قياسي
            .eq('id', schedule.id);

           // 🌟 السطر الجديد: إخبار دفتر التحديثات أن السحابة قامت بتعديل بيانات هذا المستخدم!
          await supabase
            .from('sync_metadata')
            .upsert({ 
               user_id: schedule.user_id, 
               last_updated_at: nowUtc.toISOString() 
            });


          sentCount++;
        }
      }
    }

    return new Response(`تم الإرسال بنجاح! أيقظنا ${sentCount} هواتف.`, { status: 200 });
  } catch (error: any) {
    return new Response(`خطأ: ${error.message}`, { status: 500 });
  }
});