import { useState } from 'react'
import {
  Alert,
  Button,
  Divider,
  IconButton,
  List,
  ListItem,
  ListItemText,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import PersonIcon from '@mui/icons-material/Person'
import PersonOutlineIcon from '@mui/icons-material/PersonOutline'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import AddIcon from '@mui/icons-material/Add'
import LogoutIcon from '@mui/icons-material/Logout'
import { useCreatePerson, useDeletePerson, usePeople } from '../api/hooks'
import { setMyPersonId, useMyPersonId } from '../config'
import { clearAuth, useAuth } from '../api/auth'
import { api } from '../api/client'
import { queryClient } from '../queryClient'
import QueryBoundary from '../components/QueryBoundary'

export default function SettingsPage() {
  const people = usePeople()
  const myId = useMyPersonId()
  const createPerson = useCreatePerson()
  const deletePerson = useDeletePerson()
  const { user } = useAuth()
  const [name, setName] = useState('')

  const signOut = async () => {
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
      <Typography variant="h6">Reminders</Typography>
      <Alert severity="info">
        Task reminders are delivered by the phone app as on-device notifications. The web app
        shows what&apos;s due on the dashboard; browser push reminders aren&apos;t set up yet.
      </Alert>

      <Divider />
      <Typography variant="h6">Server</Typography>
      <Typography variant="body2" color="text.secondary">
        The web app uses the same backend it&apos;s served from — no address to configure.
      </Typography>
    </Stack>
  )
}
