# ThirdBooks Design System

## Overview

ThirdBooks features a professional, industry-standard design system specifically crafted for financial and accounting applications. Our color palette and components are inspired by leading fintech products like QuickBooks, Xero, and modern banking applications.

---

## Color Palette

### Primary Color - Indigo
**Purpose:** Brand identity, primary actions, trust, professionalism

Our primary color is a sophisticated indigo that conveys trust, stability, and professionalism - essential qualities for financial software.

```
primary-50:  #eef2ff  ░░░░░░░░  Very light tint
primary-100: #e0e7ff  ░░░░░░░
primary-200: #c7d2fe  ░░░░░░
primary-300: #a5b4fc  ░░░░░
primary-400: #818cf8  ░░░░
primary-500: #6366f1  ░░░     Base color
primary-600: #4f46e5  ███     Primary buttons, links
primary-700: #4338ca  ████
primary-800: #3730a3  █████
primary-900: #312e81  ██████
primary-950: #1e1b4b  ███████  Darkest shade
```

**Usage:**
- Primary buttons and CTAs
- Active navigation items
- Links and interactive elements
- Focus states
- Loading indicators

---

### Secondary Color - Emerald Green
**Purpose:** Success states, financial growth, positive metrics, money

Emerald green represents growth, prosperity, and success - perfect for financial applications.

```
secondary-50:  #ecfdf5  ░░░░░░░░  Very light tint
secondary-100: #d1fae5  ░░░░░░░
secondary-200: #a7f3d0  ░░░░░░
secondary-300: #6ee7b7  ░░░░░
secondary-400: #34d399  ░░░░
secondary-500: #10b981  ░░░     Base color
secondary-600: #059669  ███     Success buttons, positive values
secondary-700: #047857  ████
secondary-800: #065f46  █████
secondary-900: #064e3b  ██████
secondary-950: #022c22  ███████  Darkest shade
```

**Usage:**
- Success messages and alerts
- Positive financial metrics (profit, revenue)
- Paid invoice status
- Completed status indicators
- "Record Payment" actions

---

### Accent Color - Amber
**Purpose:** Warnings, pending states, attention needed

Warm amber draws attention without being alarming, perfect for warnings and pending items.

```
accent-50:  #fffbeb  ░░░░░░░░  Very light tint
accent-100: #fef3c7  ░░░░░░░
accent-200: #fde68a  ░░░░░░
accent-300: #fcd34d  ░░░░░
accent-400: #fbbf24  ░░░░
accent-500: #f59e0b  ░░░     Base color
accent-600: #d97706  ███     Warning buttons, pending states
accent-700: #b45309  ████
accent-800: #92400e  █████
accent-900: #78350f  ██████
accent-950: #451a03  ███████  Darkest shade
```

**Usage:**
- Warning messages
- Pending/partial payment status
- Overdue but not critical items
- "Needs attention" indicators
- Draft status

---

### Neutral Grays
**Purpose:** Text, backgrounds, borders, structure

Professional gray scale for maximum readability and elegant hierarchy.

```
gray-50:  #f9fafb  ░░░░░░░░  Page backgrounds
gray-100: #f3f4f6  ░░░░░░░   Card hover states
gray-200: #e5e7eb  ░░░░░░    Borders
gray-300: #d1d5db  ░░░░░     Disabled states
gray-400: #9ca3af  ░░░░      Placeholders
gray-500: #6b7280  ░░░       Secondary text
gray-600: #4b5563  ███       Body text
gray-700: #374151  ████      Headings
gray-800: #1f2937  █████     Dark headings
gray-900: #111827  ██████    Primary text
gray-950: #030712  ███████   Maximum contrast
```

---

### Status Colors

**Success (Green)**
- `bg-green-100 text-green-800` - Paid invoices, completed tasks
- Use secondary colors for success states

**Error/Danger (Red)**
- `bg-red-100 text-red-800` - Errors, overdue items, delete actions
- Red 600 for danger buttons

**Info (Blue)**
- `bg-blue-100 text-blue-800` - Informational alerts, sent status
- Blue 600 for info buttons

**Warning (Amber)**
- `bg-amber-100 text-amber-800` - Warnings, pending states
- Accent colors for warning states

---

## Typography

### Font Family
**Primary:** Inter (Google Fonts)

Inter is a professional, highly legible typeface designed specifically for computer screens. It's used by Notion, GitHub, Stripe, and many modern financial applications.

```css
font-family: 'Inter', system-ui, -apple-system, sans-serif
```

**Font Features:**
- Optimized for digital screens
- Excellent readability at small sizes
- Professional and modern appearance
- Variable font with multiple weights

### Font Weights

```
300 - Light       (rarely used)
400 - Regular     Body text
500 - Medium      Subtle emphasis
600 - Semi-Bold   Buttons, labels
700 - Bold        Headings
800 - Extra-Bold  Large display text
```

### Type Scale

```
text-xs    0.75rem   12px   Small labels, helper text
text-sm    0.875rem  14px   Body text, table data
text-base  1rem      16px   Default body text
text-lg    1.125rem  18px   Card titles
text-xl    1.25rem   20px   Section headings
text-2xl   1.5rem    24px   Page titles
text-3xl   1.875rem  30px   Large headings
text-4xl   2.25rem   36px   Hero text
```

---

## Component Styles

### Buttons

**Primary Button** (`.btn-primary`)
- Background: Indigo 600
- Text: White
- Hover: Indigo 700
- Active: Indigo 800
- Shadow: Small, increases on hover
- Focus ring: Indigo 500

**Secondary Button** (`.btn-secondary`)
- Background: White
- Text: Gray 700
- Border: Gray 300
- Hover: Gray 50
- Active: Gray 100

**Success Button** (`.btn-success`)
- Background: Emerald 600
- Text: White
- Use for: Record payment, approve actions

**Danger Button** (`.btn-danger`)
- Background: Red 600
- Text: White
- Use for: Delete, cancel operations

**Warning Button** (`.btn-warning`)
- Background: Amber 500
- Text: White
- Use for: Cautionary actions

### Cards

**Standard Card** (`.card`)
- Background: White
- Border: Gray 100 (1px)
- Border Radius: 12px (rounded-xl)
- Padding: 24px (p-6)
- Shadow: Soft card shadow

**Hover Card** (`.card-hover`)
- Same as card
- Shadow increases on hover
- Transition: 200ms

### Forms

**Input Fields** (`.input`)
- Border: Gray 300
- Border Radius: 8px (rounded-lg)
- Focus: Indigo 500 ring
- Placeholder: Gray 400
- Shadow: Subtle inner shadow

**Labels** (`.label`)
- Font Weight: Semi-bold (600)
- Color: Gray 700
- Size: Small (text-sm)
- Margin Bottom: 6px

### Badges/Status Pills

**Badge Styles:**
```html
<!-- Paid/Success -->
<span class="badge badge-success">Paid</span>

<!-- Sent/Info -->
<span class="badge badge-info">Sent</span>

<!-- Draft -->
<span class="badge badge-gray">Draft</span>

<!-- Overdue/Error -->
<span class="badge badge-danger">Overdue</span>

<!-- Partial/Warning -->
<span class="badge badge-warning">Partial</span>
```

### Tables

**Professional Data Tables:**
- Header: Gray 50 background
- Header Text: Gray 600, uppercase, semi-bold, small
- Row Hover: Gray 50
- Borders: Gray 200
- Text: Gray 900 (sm size)

---

## Shadows

### Elevation System

```css
/* No Shadow */
shadow-none

/* Subtle Card Shadow (default) */
shadow-card: 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)

/* Small Shadow (buttons) */
shadow-sm: 0 1px 2px rgba(0,0,0,0.05)

/* Medium Shadow (hover states) */
shadow-md: 0 4px 6px rgba(0,0,0,0.1)

/* Soft Shadow (elevated cards) */
shadow-soft: 0 2px 15px rgba(0,0,0,0.07), 0 10px 20px rgba(0,0,0,0.04)

/* Large Shadow (modals) */
shadow-lg: 0 10px 15px rgba(0,0,0,0.1)

/* Extra Large (overlays) */
shadow-xl: 0 20px 25px rgba(0,0,0,0.15)
```

---

## Spacing System

Consistent spacing using Tailwind's 4px base unit:

```
0    0px      None
1    4px      Tiny
2    8px      Extra small
3    12px     Small
4    16px     Medium
5    20px
6    24px     Large (default card padding)
8    32px     Extra large
12   48px     Section spacing
16   64px     Large section spacing
```

---

## Border Radius

```
rounded-none   0px       No rounding
rounded-sm     2px       Subtle
rounded        4px       Default
rounded-md     6px       Medium
rounded-lg     8px       Inputs, buttons
rounded-xl     12px      Cards, containers
rounded-2xl    16px      Large cards
rounded-full   9999px    Pills, badges, avatars
```

---

## Icons

**Recommended:** Heroicons (already used throughout)
- Line style for most icons
- Solid style for filled states
- 20px (h-5 w-5) for buttons and inline
- 24px (h-6 w-6) for stat cards
- 48px (h-12 w-12) for empty states

---

## Animation & Transitions

### Duration

```css
duration-150  150ms   Quick transitions
duration-200  200ms   Default (buttons, cards)
duration-300  300ms   Modals, page transitions
```

### Easing

```css
ease-in-out   Default for most transitions
ease-out      For appearing elements
ease-in       For disappearing elements
```

### Common Transitions

```css
transition-colors     Color changes
transition-shadow     Shadow changes
transition-all        All properties (use sparingly)
```

---

## Accessibility

### Color Contrast

All text meets WCAG AA standards:
- Large text (18px+): 3:1 minimum
- Normal text: 4.5:1 minimum
- Interactive elements: Clear focus indicators

### Focus States

All interactive elements have visible focus rings:
```css
focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2
```

### Screen Reader Support

- Semantic HTML elements
- ARIA labels where needed
- Skip navigation links
- Descriptive alt text

---

## Best Practices

### Do's ✅

- Use primary color for main actions
- Use secondary (green) for positive financial metrics
- Use consistent spacing (multiples of 4)
- Maintain proper color contrast
- Use shadows sparingly for depth
- Keep font weights consistent
- Use rounded corners (8px-12px) for modern feel

### Don'ts ❌

- Don't mix multiple accent colors
- Don't use pure black (#000) - use gray-900
- Don't use colors alone to convey meaning
- Don't forget focus states
- Don't use tiny font sizes (below 12px)
- Don't overuse animations
- Don't create new spacing values

---

## Component Examples

### Financial Metric Card

```html
<div class="card">
  <div class="flex items-center">
    <div class="flex-shrink-0 bg-primary-500 rounded-xl p-3">
      <svg class="h-6 w-6 text-white">...</svg>
    </div>
    <div class="ml-5 flex-1">
      <dt class="text-sm font-medium text-gray-500 uppercase tracking-wide">
        Revenue
      </dt>
      <dd class="text-2xl font-bold text-gray-900">
        UGX 1,250,000
      </dd>
    </div>
  </div>
</div>
```

### Status Badge

```html
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Paid
</span>
```

### Primary Action Button

```html
<button class="btn btn-primary">
  Create Invoice
</button>
```

---

## Resources

- **Tailwind CSS Documentation:** https://tailwindcss.com
- **Inter Font:** https://fonts.google.com/specimen/Inter
- **Heroicons:** https://heroicons.com
- **Color Contrast Checker:** https://webaim.org/resources/contrastchecker/

---

## Version History

- **v1.0** (Current) - Initial professional design system
  - Indigo primary color
  - Emerald secondary color
  - Amber accent color
  - Inter typography
  - Comprehensive component library
