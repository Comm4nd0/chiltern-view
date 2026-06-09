import { createTheme } from '@mui/material/styles'

// An Apple-flavoured theme: SF system font, iOS "grouped" background with white
// cards, hairline separators, soft shadows and pill buttons. Teal (#00796B,
// Marco & Claire's favourite) stays the accent. Kept in sync with the Flutter
// app's theme.dart so web and mobile feel like the same product.

const SF =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif'

// iOS-style palette tokens.
const TEAL = '#00796B'
const LABEL = '#1C1C1E'
const SECONDARY_LABEL = '#6E6E73'
const GROUPED_BG = '#F2F2F7'
const SEPARATOR = 'rgba(60, 60, 67, 0.16)'

// Soft, layered card shadow — closer to iOS depth than Material elevation.
const CARD_SHADOW = '0 1px 2px rgba(0,0,0,0.04), 0 6px 20px rgba(0,0,0,0.06)'

export const theme = createTheme({
  palette: {
    primary: { main: TEAL, light: '#4DA99C', dark: '#005B4F' },
    secondary: { main: '#FF9500' },
    error: { main: '#FF3B30' },
    warning: { main: '#FF9500' },
    success: { main: '#34C759' },
    info: { main: '#007AFF' },
    background: { default: GROUPED_BG, paper: '#FFFFFF' },
    text: { primary: LABEL, secondary: SECONDARY_LABEL },
    divider: SEPARATOR,
  },
  shape: { borderRadius: 14 },
  typography: {
    fontFamily: SF,
    // Tighter tracking on headings, the way SF Pro Display is set on iOS.
    h4: { fontWeight: 700, letterSpacing: '-0.02em' },
    h5: { fontWeight: 700, letterSpacing: '-0.02em' },
    h6: { fontWeight: 700, letterSpacing: '-0.015em' },
    subtitle1: { fontWeight: 600, letterSpacing: '-0.01em' },
    subtitle2: { fontWeight: 600 },
    button: { fontWeight: 600, textTransform: 'none', letterSpacing: 0 },
    caption: { letterSpacing: 0 },
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: { backgroundColor: GROUPED_BG, WebkitFontSmoothing: 'antialiased' },
      },
    },
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: {
          borderRadius: 16,
          boxShadow: CARD_SHADOW,
          backgroundImage: 'none',
        },
      },
    },
    MuiPaper: {
      styleOverrides: { rounded: { borderRadius: 16 } },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: { borderRadius: 980, paddingInline: 18, minHeight: 38 },
        sizeSmall: { minHeight: 32, paddingInline: 14 },
        containedPrimary: { boxShadow: 'none' },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: { borderRadius: 980, fontWeight: 600 },
        filled: { backgroundColor: 'rgba(120,120,128,0.12)' },
      },
    },
    MuiTab: {
      styleOverrides: {
        root: { textTransform: 'none', fontWeight: 600, letterSpacing: 0, minHeight: 48 },
      },
    },
    MuiDivider: {
      styleOverrides: { root: { borderColor: SEPARATOR } },
    },
    MuiListItemButton: {
      styleOverrides: { root: { borderRadius: 12 } },
    },
    MuiOutlinedInput: {
      styleOverrides: { root: { borderRadius: 12 } },
    },
    MuiDialog: {
      styleOverrides: { paper: { borderRadius: 20 } },
    },
  },
})

/** Colour used to flag a care task's urgency (matches the Flutter app). */
export function statusColor(status: string): string {
  switch (status) {
    case 'overdue':
      return '#FF3B30' // iOS red
    case 'due_today':
      return '#FF9500' // iOS orange
    default:
      return TEAL
  }
}
