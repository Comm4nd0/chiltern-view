import { AppBar, Box, Container, IconButton, Tab, Tabs, Toolbar, Typography } from '@mui/material'
import SettingsIcon from '@mui/icons-material/Settings'
import { Link, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import OverviewPage from './pages/OverviewPage'
import DashboardPage from './pages/DashboardPage'
import CropsPage from './pages/CropsPage'
import AnimalsPage from './pages/AnimalsPage'
import SettingsPage from './pages/SettingsPage'

const tabs = [
  { label: 'Home', path: '/' },
  { label: 'To do', path: '/todo' },
  { label: 'Crops', path: '/crops' },
  { label: 'Animals', path: '/animals' },
]

export default function App() {
  const location = useLocation()
  const navigate = useNavigate()
  const current = tabs.findIndex((t) => t.path === location.pathname)

  return (
    <Box>
      <AppBar position="sticky">
        <Toolbar>
          <Typography variant="h6" sx={{ flex: 1 }}>
            Chiltern View
          </Typography>
          <IconButton color="inherit" component={Link} to="/settings" aria-label="Settings">
            <SettingsIcon />
          </IconButton>
        </Toolbar>
        <Tabs
          value={current === -1 ? false : current}
          onChange={(_, v: number) => navigate(tabs[v].path)}
          textColor="inherit"
          variant="fullWidth"
          sx={{ '& .MuiTabs-indicator': { backgroundColor: 'white' } }}
        >
          {tabs.map((t) => (
            <Tab key={t.path} label={t.label} />
          ))}
        </Tabs>
      </AppBar>
      <Container maxWidth="sm" sx={{ py: 2 }}>
        <Routes>
          <Route path="/" element={<OverviewPage />} />
          <Route path="/todo" element={<DashboardPage />} />
          <Route path="/crops" element={<CropsPage />} />
          <Route path="/animals" element={<AnimalsPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </Container>
    </Box>
  )
}
