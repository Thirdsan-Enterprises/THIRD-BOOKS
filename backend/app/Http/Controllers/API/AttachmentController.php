<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Attachment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class AttachmentController extends Controller
{
    /**
     * Global list of all attachments for the company.
     *
     * GET /attachments
     * Optional filters: ?type=invoice&id=5  or  ?attachable_type=App\Models\Sales\Invoice
     */
    public function index(Request $request)
    {
        $query = Attachment::with('uploader')
            ->orderByDesc('created_at');

        // Filter by human-friendly type name (invoice, bill, journal-entry, bill-payment, payment)
        if ($request->has('type')) {
            $morphMap = self::morphMap();
            $type = $morphMap[$request->type] ?? null;
            if ($type) {
                $query->where('attachable_type', $type);
            }
        }

        // Filter down to a specific model instance
        if ($request->has('attachable_type') && $request->has('attachable_id')) {
            $query->where('attachable_type', $request->attachable_type)
                  ->where('attachable_id', $request->attachable_id);
        }

        $perPage = $request->input('per_page', 50);

        return response()->json($query->paginate($perPage));
    }

    /**
     * Upload one or more attachments to a given document.
     *
     * POST /attachments
     * Body (multipart/form-data):
     *   - attachable_type: "invoice" | "bill" | "journal-entry" | "bill-payment" | "payment" | "bank-statement"
     *   - attachable_id:   integer
     *   - files[]:         file upload(s)
     *   - labels[]:        optional label per file (same index as files[])
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'attachable_type'  => 'required|string|in:invoice,bill,journal-entry,bill-payment,payment,bank-statement',
            'attachable_id'    => 'required|integer|min:1',
            'files'            => 'required|array|min:1',
            'files.*'          => 'required|file|max:20480|mimes:pdf,jpg,jpeg,png,gif,webp,xlsx,xls,csv,doc,docx,txt',
            'labels'           => 'nullable|array',
            'labels.*'         => 'nullable|string|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $morphMap  = self::morphMap();
        $modelClass = $morphMap[$request->attachable_type];

        // Verify the parent record exists
        if (!$modelClass::find($request->attachable_id)) {
            return response()->json(['message' => 'Parent record not found'], 404);
        }

        $companyId = $request->user()->company_id ?? $request->input('company_id');
        $disk      = config('filesystems.default', 'local');
        $created   = [];

        foreach ($request->file('files') as $index => $file) {
            $originalName = $file->getClientOriginalName();
            $storagePath  = 'attachments/' . date('Y/m') . '/' . Str::uuid() . '.' . $file->getClientOriginalExtension();

            $file->storeAs(dirname($storagePath), basename($storagePath), ['disk' => $disk]);

            $attachment = Attachment::create([
                'company_id'      => $companyId,
                'attachable_type' => $modelClass,
                'attachable_id'   => $request->attachable_id,
                'file_name'       => $originalName,
                'file_path'       => $storagePath,
                'disk'            => $disk,
                'mime_type'       => $file->getMimeType(),
                'file_size'       => $file->getSize(),
                'label'           => $request->input("labels.{$index}"),
                'uploaded_by'     => $request->user()?->id,
            ]);

            $created[] = $attachment->fresh(['uploader']);
        }

        return response()->json([
            'message'     => count($created) . ' attachment(s) uploaded successfully',
            'attachments' => $created,
        ], 201);
    }

    /**
     * Show a single attachment (with a signed URL).
     *
     * GET /attachments/{id}
     */
    public function show($id)
    {
        $attachment = Attachment::with(['attachable', 'uploader'])->findOrFail($id);

        return response()->json(['attachment' => $attachment]);
    }

    /**
     * Delete an attachment (soft-delete; physical file removed on force-delete).
     *
     * DELETE /attachments/{id}
     */
    public function destroy($id)
    {
        $attachment = Attachment::findOrFail($id);

        // Also delete the physical file immediately
        if ($attachment->file_path) {
            Storage::disk($attachment->disk)->delete($attachment->file_path);
        }

        $attachment->forceDelete();

        return response()->json(['message' => 'Attachment deleted successfully']);
    }

    /**
     * Map friendly type names → fully-qualified model class names.
     */
    private static function morphMap(): array
    {
        return [
            'invoice'        => \App\Models\Sales\Invoice::class,
            'bill'           => \App\Models\Purchases\Bill::class,
            'journal-entry'  => \App\Models\Accounting\JournalEntry::class,
            'bill-payment'   => \App\Models\Purchases\BillPayment::class,
            'payment'        => \App\Models\Sales\Payment::class,
            'bank-statement' => \App\Models\Banking\BankStatement::class,
        ];
    }
}
