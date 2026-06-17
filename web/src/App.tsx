import {
  AppBar,
  Box,
  BottomNavigation,
  BottomNavigationAction,
  Container,
  IconButton,
  Paper,
  Toolbar,
  Typography,
} from '@mui/material'
import { House, ListChecks, Plant, PawPrint, Gear } from '@phosphor-icons/react'
import { Link, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import OverviewPage from './pages/OverviewPage'
import DashboardPage from './pages/DashboardPage'
import CropsPage from './pages/CropsPage'
import AnimalsPage from './pages/AnimalsPage'
import AnimalDetailPage from './pages/AnimalDetailPage'
import EggLogPage from './pages/EggLogPage'
import SettingsPage from './pages/SettingsPage'
import ActivityPage from './pages/ActivityPage'
import LoginPage from './pages/LoginPage'
import { useAuth } from './api/auth'

const tabs = [
  { label: 'Home', path: '/', icon: House },
  { label: 'To do', path: '/todo', icon: ListChecks },
  { label: 'Crops', path: '/crops', icon: Plant },
  { label: 'Animals', path: '/animals', icon: PawPrint },
]

const titles: Record<string, string> = {
  '/': 'Home',
  '/todo': 'To do',
  '/crops': 'Crops',
  '/animals': 'Animals',
  '/eggs': 'Eggs',
  '/activity': 'Activity',
  '/settings': 'Settings',
}

export default function App() {
  const { token } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  // Nested pages (e.g. /animals/3) keep their section's tab highlighted.
  const current = tabs.findIndex((t) =>
    t.path === '/' ? location.pathname === '/' : location.pathname.startsWith(t.path),
  )
  const title =
    titles[location.pathname] ?? (location.pathname.startsWith('/animals/') ? 'Animal' : 'Chiltern View')

  // Not signed in → the login screen replaces the whole shell.
  if (!token) return <LoginPage />

  return (
    <Box sx={{ minHeight: '100dvh', bgcolor: 'background.default' }}>
      {/* iOS-style translucent large-title header */}
      <AppBar
        position="sticky"
        elevation={0}
        sx={{
          bgcolor: 'rgba(248,248,250,0.8)',
          backdropFilter: 'blur(20px)',
          color: 'text.primary',
          borderBottom: '1px solid',
          borderColor: 'divider',
        }}
      >
        <Toolbar sx={{ maxWidth: 'sm', width: '100%', mx: 'auto' }}>
          <Typography variant="h5" sx={{ flex: 1, fontWeight: 800 }}>
            {title}
          </Typography>
          <IconButton
            component={Link}
            to="/settings"
            aria-label="Settings"
            sx={{ color: 'text.secondary' }}
          >
            <Gear size={24} weight={location.pathname === '/settings' ? 'fill' : 'regular'} />
          </IconButton>
        </Toolbar>
      </AppBar>

      <Container maxWidth="sm" sx={{ py: 2, pb: 12 }}>
        <Routes>
          <Route path="/" element={<OverviewPage />} />
          <Route path="/todo" element={<DashboardPage />} />
          <Route path="/crops" element={<CropsPage />} />
          <Route path="/animals" element={<AnimalsPage />} />
          <Route path="/animals/:id" element={<AnimalDetailPage />} />
          <Route path="/eggs" element={<EggLogPage />} />
          <Route path="/activity" element={<ActivityPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </Container>

      {/* iOS-style bottom tab bar */}
      <Paper
        elevation={0}
        sx={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          borderRadius: 0,
          borderTop: '1px solid',
          borderColor: 'divider',
          bgcolor: 'rgba(248,248,250,0.85)',
          backdropFilter: 'blur(20px)',
          zIndex: (t) => t.zIndex.appBar,
        }}
      >
        <BottomNavigation
          value={current === -1 ? false : current}
          showLabels
          onChange={(_, v: number) => navigate(tabs[v].path)}
          sx={{
            bgcolor: 'transparent',
            maxWidth: 'sm',
            mx: 'auto',
            '& .MuiBottomNavigationAction-label': { fontSize: 11, mt: 0.5 },
          }}
        >
          {tabs.map((t, i) => {
            const Icon = t.icon
            return (
              <BottomNavigationAction
                key={t.path}
                label={t.label}
                icon={<Icon size={26} weight={current === i ? 'fill' : 'regular'} />}
              />
            )
          })}
        </BottomNavigation>
      </Paper>
    </Box>
  )
}
