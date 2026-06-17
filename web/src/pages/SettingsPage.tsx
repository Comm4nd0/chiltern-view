import { useEffect, useState } from 'react'
import {
  Alert,
  Button,
  CircularProgress,
  Divider,
  FormControlLabel,
  IconButton,
  List,
  ListItem,
  ListItemText,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material'
import PersonIcon from '@mui/icons-material/Person'
import PersonOutlineIcon from '@mui/icons-material/PersonOutline'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import AddIcon from '@mui/icons-material/Add'
import LogoutIcon from '@mui/icons-material/Logout'
import { useNavigate } from 'react-router-dom'
import InventoryIcon from '@mui/icons-material/Inventory2Outlined'
import { useCreatePerson, useDeletePerson, usePeople } from '../api/hooks'
import { setMyPersonId, useMyPersonId } from '../config'
import { clearAuth, useAuth } from '../api/auth'
import { api, downloadExport } from '../api/client'
import { queryClient } from '../queryClient'
import QueryBoundary from '../components/QueryBoundary'
import { disablePush, enablePush, getPushState, type PushState } from '../push'

/** The browser-reminders toggle: the web counterpart of the phone app's
 * on-device notifications (a morning digest + due-today pings). */
function ReminderSettings() {
  const [state, setState] = useState<PushState | 'loading'>('loading')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    void getPushState().then(setState)
  }, [])

  const toggle = async (on: boolean) => {
    setBusy(true)
    setError(null)
    try {
      if (on) await enablePush()
      else await disablePush()
      setState(await getPushState())
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not change reminders.')
      setState(await getPushState())
    } finally {
      setBusy(false)
    }
  }

  if (state === 'loading') return <CircularProgress size={20} />
  if (state === 'unsupported') {
    return (
      <Alert severity="info">
        This browser doesn't support push notifications. The phone app delivers reminders
        on-device, and the dashboard always shows what's due.
      </Alert>
    )
  }
  if (state === 'denied') {
    return (
      <Alert severity="warning">
        Notifications are blocked for this site. Allow them in the browser's site settings,
        then come back and switch reminders on.
      </Alert>
    )
  }
  return (
    <Stack spacing={1}>
      <FormControlLabel
        control={
          <Switch checked={state === 'on'} disabled={busy} onChange={(e) => toggle(e.target.checked)} />
        }
        label="Browser reminders"
      />
      <Typography variant="body2" color="text.secondary">
        A morning summary of what's due, plus a nudge for tasks due that day — the same
        reminders the phone app sends. On iPhone, add this site to the Home Screen first
        (Share → Add to Home Screen).
      </Typography>
      {error && (
        <Typography color="error" variant="body2">
          {error}
        </Typography>
      )}
    </Stack>
  )
}

export default function SettingsPage() {
  const navigate = useNavigate()
  const people = usePeople()
  const myId = useMyPersonId()
  const createPerson = useCreatePerson()
  const deletePerson = useDeletePerson()
  const { user } = useAuth()
  const [name, setName] = useState('')
  const [exportError, setExportError] = useState<string | null>(null)

  const signOut = async () => {
    // This browser's reminders belong to whoever is signed in — drop the
    // subscription so the next person doesn't inherit them.
    await disablePush().catch(() => {})
    try {
      await api.logout()
    } catch {
      // Even if the network call fails, drop local creds and return to login.
    }
    clearAuth()
    queryClient.clear()
  }

  const add = async () => {
    if (!name.trim()) return
    await createPerson.mutateAsync(name.trim())
    setName('')
  }

  return (
    <Stack spacing={2}>
      <Typography variant="h6">Account</Typography>
      <Typography variant="body2" color="text.secondary">
        Signed in as {user?.username ?? '…'}.
      </Typography>
      <Button
        variant="outlined"
        color="error"
        startIcon={<LogoutIcon />}
        onClick={signOut}
        sx={{ alignSelf: 'flex-start' }}
      >
        Sign out
      </Button>
      <Divider />

      <Typography variant="h6">People</Typography>
      <Typography variant="body2" color="text.secondary">
        Add yourself and one other, then tap the person icon to mark which one is you in this
        browser. The dashboard defaults to your tasks, and new tasks default to you.
      </Typography>

      <QueryBoundary query={people}>
        {(list) =>
          list.length === 0 ? (
            <Typography color="text.secondary">No people yet.</Typography>
          ) : (
            <List disablePadding>
              {list.map((p) => (
                <ListItem
                  key={p.id}
                  disableGutters
                  secondaryAction={
                    <IconButton
                      edge="end"
                      aria-label="Delete"
                      onClick={() => deletePerson.mutate(p.id)}
                    >
                      <DeleteOutlineIcon />
                    </IconButton>
                  }
                >
                  <IconButton
                    onClick={() => setMyPersonId(p.id === myId ? null : p.id)}
                    aria-label="Mark as me"
                    sx={{ mr: 1 }}
                  >
                    {p.id === myId ? <PersonIcon color="primary" /> : <PersonOutlineIcon />}
                  </IconButton>
                  <ListItemText
                    primary={p.name}
                    secondary={p.id === myId ? 'This browser' : undefined}
                  />
                </ListItem>
              ))}
            </List>
          )
        }
      </QueryBoundary>

      <Stack direction="row" spacing={1}>
        <TextField
          fullWidth
          size="small"
          label="Add a person"
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') void add()
          }}
        />
        <IconButton color="primary" onClick={add} aria-label="Add person">
          <AddIcon />
        </IconButton>
      </Stack>

      <Divider />
      <Typography variant="h6">Holding</Typography>
      <Button
        variant="outlined"
        startIcon={<InventoryIcon />}
        onClick={() => navigate('/supplies')}
        sx={{ alignSelf: 'flex-start' }}
      >
        Feed &amp; supplies
      </Button>

      <Divider />
      <Typography variant="h6">Export data</Typography>
      <Typography variant="body2" color="text.secondary">
        Download a CSV backup of any part of the holding.
      </Typography>
      <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', rowGap: 1 }}>
        {(['animals', 'crops', 'eggs', 'weights', 'supplies', 'journal'] as const).map((d) => (
          <Button
            key={d}
            size="small"
            variant="outlined"
            onClick={() => downloadExport(d).catch(() => setExportError('Export failed.'))}
            sx={{ textTransform: 'capitalize' }}
          >
            {d}
          </Button>
        ))}
      </Stack>
      {exportError && (
        <Typography color="error" variant="body2">
          {exportError}
        </Typography>
      )}

      <Divider />
      <Typography variant="h6">Reminders</Typography>
      <ReminderSettings />

      <Divider />
      <Typography variant="h6">Server</Typography>
      <Typography variant="body2" color="text.secondary">
        The web app uses the same backend it&apos;s served from — no address to configure.
      </Typography>
    </Stack>
  )
}
