import { createTheme } from '@mui/material/styles'

// Smallholding green, matching the Flutter app.
export const theme = createTheme({
  palette: {
    primary: { main: '#4F772D' },
    background: { default: '#f6f7f2' },
  },
  shape: { borderRadius: 12 },
})

/** Colour used to flag a care task's urgency (matches the Flutter app). */
export function statusColor(status: string): string {
  switch (status) {
    case 'overdue':
      return '#C0392B'
    case 'due_today':
      return '#E67E22'
    default:
      return '#4F772D'
  }
}
