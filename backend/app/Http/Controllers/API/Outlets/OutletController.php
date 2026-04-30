<?php

namespace App\Http\Controllers\API\Outlets;

use App\Http\Controllers\Controller;
use App\Models\Outlet;
use Database\Seeders\OutletSeeder;
use Illuminate\Http\Request;

class OutletController extends Controller
{
    /** GET /api/outlets */
    public function index(Request $request)
    {
        $outlets = Outlet::query()
            ->when($request->region, fn($q, $r) => $q->where('region', $r))
            ->when($request->active !== null, fn($q) => $q->where('is_active', (bool) $request->active))
            ->orderBy('outlet_code')
            ->get();

        return response()->json(['data' => $outlets]);
    }

    /** GET /api/outlets/{id} */
    public function show(Outlet $outlet)
    {
        return response()->json(['data' => $outlet]);
    }

    /** POST /api/outlets */
    public function store(Request $request)
    {
        $data = $request->validate([
            'outlet_code'     => 'required|string|unique:outlets,outlet_code',
            'name'            => 'required|string',
            'address'         => 'nullable|string',
            'city'            => 'nullable|string',
            'postal_code'     => 'nullable|string',
            'region'          => 'nullable|string',
            'venue_type'      => 'nullable|string',
            'owner_name'      => 'nullable|string',
            'owner_contact'   => 'nullable|string',
            'commission_rate' => 'nullable|numeric|between:0,100',
            'is_active'       => 'nullable|boolean',
            'notes'           => 'nullable|string',
        ]);

        $outlet = Outlet::create($data);
        return response()->json(['data' => $outlet], 201);
    }

    /** PUT /api/outlets/{id} */
    public function update(Request $request, Outlet $outlet)
    {
        $data = $request->validate([
            'outlet_code'     => 'sometimes|string|unique:outlets,outlet_code,' . $outlet->id,
            'name'            => 'sometimes|string',
            'address'         => 'nullable|string',
            'city'            => 'nullable|string',
            'postal_code'     => 'nullable|string',
            'region'          => 'nullable|string',
            'venue_type'      => 'nullable|string',
            'owner_name'      => 'nullable|string',
            'owner_contact'   => 'nullable|string',
            'commission_rate' => 'nullable|numeric|between:0,100',
            'is_active'       => 'nullable|boolean',
            'notes'           => 'nullable|string',
        ]);

        $outlet->update($data);
        return response()->json(['data' => $outlet]);
    }

    /** DELETE /api/outlets/{id} */
    public function destroy(Outlet $outlet)
    {
        $outlet->delete();
        return response()->json(null, 204);
    }

    /**
     * POST /api/outlets/seed
     * Re-seeds all 72 default MagicBet outlets (idempotent — safe to call again).
     */
    public function seed()
    {
        $seeder = new OutletSeeder();
        $seeder->run();

        $count = Outlet::count();
        return response()->json([
            'message' => "Outlets seeded successfully. Total: {$count}",
            'count'   => $count,
        ]);
    }
}
