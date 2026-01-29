@props([
    'title',
    'value',
    'icon' => null,
    'change' => null,
    'changeType' => 'neutral', // positive, negative, neutral
    'href' => null,
])

<div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 {{ $href ? 'hover:shadow-md transition-shadow cursor-pointer' : '' }}"
     @if($href) onclick="window.location.href='{{ $href }}'" @endif>
    <div class="flex items-center justify-between">
        <div>
            <p class="text-sm font-medium text-gray-500 uppercase tracking-wide">{{ $title }}</p>
            <p class="mt-2 text-3xl font-bold text-gray-900">{{ $value }}</p>

            @if($change)
                <div class="mt-2 flex items-center text-sm">
                    @if($changeType === 'positive')
                        <svg class="w-4 h-4 text-green-500 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"/>
                        </svg>
                        <span class="text-green-600">{{ $change }}</span>
                    @elseif($changeType === 'negative')
                        <svg class="w-4 h-4 text-red-500 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3"/>
                        </svg>
                        <span class="text-red-600">{{ $change }}</span>
                    @else
                        <span class="text-gray-500">{{ $change }}</span>
                    @endif
                </div>
            @endif
        </div>

        @if($icon)
            <div class="p-3 bg-primary-50 rounded-lg">
                {!! $icon !!}
            </div>
        @endif
    </div>

    {{ $slot }}
</div>
