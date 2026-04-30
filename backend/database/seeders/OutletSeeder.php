<?php

namespace Database\Seeders;

use App\Models\Outlet;
use Illuminate\Database\Seeder;

/**
 * Seeds the 72 MagicBet outlets from the original outlet_data.json.
 * Safe to re-run — uses updateOrCreate so existing rows are not duplicated.
 */
class OutletSeeder extends Seeder
{
    public function run(): void
    {
        $outlets = [
            ['outlet_code'=>'23103000','name'=>'MAGIC BET YUMBE','address'=>'YUMBE','city'=>'YUMBE TOWN','region'=>'WEST NILE','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103001','name'=>'MAGIC BET ELEGU','address'=>'ELUGU','city'=>'AMURU','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103002','name'=>'MAGIC BET GALAXY LIRA','address'=>'LIRA','city'=>'LIRA','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103003','name'=>'MAGIC BET APA SLOTS','address'=>'ELUGU','city'=>'AMURU','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103004','name'=>'MAGIC BET LIRA BAR','address'=>'LIRA','city'=>'LIRA','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103005','name'=>'MAGIC BET KASENSERO','address'=>'KASENSERO','city'=>'RAKAI','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103006','name'=>'MAGIC BET MUTUKULA','address'=>'MUTUKULA','city'=>'KYOTERA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103007','name'=>'MAGIC BET ROIIKO','address'=>'ELUGU','city'=>'AMURU','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103008','name'=>'MAGIC BET DOWN TOWN','address'=>'ELUGU','city'=>'AMURU','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103009','name'=>'MAGIC BET NEBI SLOTS','address'=>'GORI','city'=>'NEBBI','region'=>'WEST NILE','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103010','name'=>'MAGIC BET LYAKAHUNGU','address'=>'LYAKAHUNGU','city'=>'KAMWENGE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103011','name'=>'MAGIC BET KANYARUGIRI','address'=>'BIHANGA','city'=>'IBANDA','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103012','name'=>'MAGIC BET LWEMIYAGA','address'=>'LWEMIYAGA','city'=>'SEMBABULE','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103013','name'=>'MAGIC BET NYABITANGA','address'=>'NYABITANGA','city'=>'SEMBABULE','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103014','name'=>'MAGIC BET NTUUSI','address'=>'NTUUSI','city'=>'SEMBABULE','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103015','name'=>'MAGIC BET BUKASA','address'=>'BUKASA','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103016','name'=>'MAGIC BET BAKKA SLOTS','address'=>'MENDE','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103017','name'=>'MAGIC BET MPERERWE','address'=>'MPERERWE','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103018','name'=>'MAGIC BET KATWE','address'=>'KATWE','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103019','name'=>'MAGIC BET KIBUYE','address'=>'KIBUYE','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103020','name'=>'MAGIC BET NAMASOLE','address'=>'MAKINDYE','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103021','name'=>'MAGIC BET NANSANA','address'=>'NANSANA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103022','name'=>'MAGIC BET KASENYI','address'=>'KASENYI','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103023','name'=>'MAGIC BET RUKUNGIRI','address'=>'RUKUNGIRI','city'=>'RUKUNGIRI','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103024','name'=>'MAGIC BET KISORO','address'=>'KISORO','city'=>'KISORO','region'=>'SOUTH WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103025','name'=>'MAGIC BET TAX PARK','address'=>'RUKUNGIRI','city'=>'RUKUNGIRI','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103026','name'=>'MAGIC BET KISORO BAR','address'=>'KISORO','city'=>'KISORO','region'=>'SOUTH WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103027','name'=>'MAGIC BET KITI','address'=>'KITI','city'=>'KALUNGU','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103028','name'=>'MAGIC BET GAYAZA','address'=>'GAYAZA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103029','name'=>'MAGIC BET MATUGA','address'=>'MATUGA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103030','name'=>'MAGIC BET KAMULI','address'=>'KASAMBILA','city'=>'KAMULI','region'=>'EAST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103031','name'=>'MAGIC BET KITORO','address'=>'ENTEBBE','city'=>'ENTEBBE','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103032','name'=>'MAGIC BET GARUGA','address'=>'GARUGA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103033','name'=>'MAGIC BET ABAYITA','address'=>'ABAYITA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103034','name'=>'MAGIC BET BUSABALA','address'=>'BUSABALA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103035','name'=>'MAGIC BET MASITOWA','address'=>'NANSANA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103036','name'=>'MAGIC BET NAKULABYE 2','address'=>'NAKULABYE','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103037','name'=>'MAGIC BET KAWUKU','address'=>'KAWUKU','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103038','name'=>'MAGIC BET KASANDA','address'=>'KASANDA','city'=>'KASANDA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103039','name'=>'MAGIC BET MPERERWE NEW','address'=>'MPERERWE','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103040','name'=>'MAGIC BET MUKONO','address'=>'MUKONO','city'=>'MUKONO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103041','name'=>'MAGIC BET NEW SLOT','address'=>'KAMPALA','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103042','name'=>'MAGIC BET ENTEBBE NEW (KITALA)','address'=>'ENTEBBE','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103043','name'=>'MAGIC BET ABAYITA ABAIRI 2','address'=>'ABAYITA ABAIRI','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103044','name'=>'MAGIC BET BULINDO','address'=>'BULINDO','city'=>'KIRA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103045','name'=>'MAGIC BET NAGULU','address'=>'NAGULU','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103046','name'=>'MAGIC BET TRUST INN','address'=>'BWERA','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103047','name'=>'MAGIC BET ANOTHER LIFE','address'=>'KASESE','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103048','name'=>'MAGIC BET SILVER SPRINGS','address'=>'KASESE','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103049','name'=>'MAGIC BET MARIBA','address'=>'KASESE','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103050','name'=>'MAGIC BET TROPICAL INN','address'=>'KASESE','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103051','name'=>'MAGIC BET KIWALA','address'=>'MUKONO','city'=>'MUKONO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103052','name'=>'MAGIC BET NAMAYIBA','address'=>'KAMPALA','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103053','name'=>'MAGIC BET KITUKUTWE','address'=>'KIRA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103054','name'=>'MAGIC BET PLAN B','address'=>'GULU','city'=>'GULU','region'=>'NORTH','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103055','name'=>'MAGIC BET B PUB','address'=>'MASINDI','city'=>'MASINDI','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103056','name'=>'MAGIC BET NAMAWOJOLO','address'=>'NAMAWOJOLO','city'=>'MUKONO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103057','name'=>'MAGIC BET KOSOVO','address'=>'KOSOVO','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103058','name'=>'MAGIC BET KITEZI','address'=>'KITEZI','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103059','name'=>'MAGIC BET MANAFWA','address'=>'MANAFWA','city'=>'MANAFWA','region'=>'EAST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103060','name'=>'MAGIC BET TRIPOLI BAR','address'=>'KASESE','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103061','name'=>'MAGIC BET ENTEBBE 3','address'=>'ENTEBBE','city'=>'ENTEBBE','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103062','name'=>'MAGIC BET NANSANA 3','address'=>'NANSANA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103063','name'=>'MAGIC BET NKUMBA','address'=>'NKUMBA','city'=>'ENTEBBE','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103064','name'=>'MAGIC BET MPALA','address'=>'MPALA','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103065','name'=>'MAGIC BET KAMULI 2','address'=>'KAMULI','city'=>'KAMULI','region'=>'EAST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103066','name'=>'MAGIC BET KAWUKU 2','address'=>'KAWUKU','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103067','name'=>'MAGIC BET APONYE','address'=>'KAMPALA','city'=>'KAMPALA','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103068','name'=>'MAGIC BET KASESE','address'=>'KASESE','city'=>'KASESE','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103069','name'=>'MAGIC BET NABINGO','address'=>'NABINGO','city'=>'WAKISO','region'=>'CENTRAL','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103070','name'=>'MAGIC BET KISORO 2','address'=>'KISORO','city'=>'KISORO','region'=>'WEST','venue_type'=>'OUTLET'],
            ['outlet_code'=>'23103071','name'=>'MAGIC BET KAMWENGE','address'=>'KAMWENGE','city'=>'KAMWENGE','region'=>'WEST','venue_type'=>'OUTLET'],
        ];

        $now = now();
        foreach ($outlets as $data) {
            Outlet::updateOrCreate(
                ['outlet_code' => $data['outlet_code']],
                array_merge($data, [
                    'commission_rate' => 40.00,
                    'is_active'       => true,
                    'updated_at'      => $now,
                ])
            );
        }

        $this->command->info('✅ ' . count($outlets) . ' outlets seeded successfully.');
    }
}
