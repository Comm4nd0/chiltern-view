import { useState } from 'react'
import type { FormEvent } from 'react'
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { Plant } from '@phosphor-icons/react'
import { api } from '../api/client'
import { setAuth } from '../api/auth'
import { getMyPersonId, setMyPersonId } from '../config'

/** Sign-in dialog shown on top of the read-only app — opened by the "Sign in"
 * button or when a write is attempted while signed out. */
export default function LoginDialog({ onClose }: { onClose: () => void }) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setError(null)
    setBusy(true)
    try {
      const { token, user } = await api.login(username.trim(), password)
      // Default "me" to the linked person on first sign-in, for task assignment.
      if (user.person_id != null && getMyPersonId() == null) setMyPersonId(user.person_id)
      setAuth(token, user) // dismisses the prompt; unlocks write controls
      onClose()
    } catch {
      setError('Wrong username or password.')
      setBusy(false)
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <form onSubmit={submit}>
        <DialogContent>
          <Box
            sx={{
              width: 56,
              height: 56,
              borderRadius: 4,
              mx: 'auto',
              mb: 1.5,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              bgcolor: 'rgba(0,121,107,0.12)',
              color: 'primary.main',
            }}
          >
            <Plant size={32} weight="fill" />
          </Box>
          <Typography variant="h6" align="center" fontWeight={800}>
            Sign in
          </Typography>
          <Typography variant="body2" align="center" color="text.secondary" sx={{ mb: 2 }}>
            Browsing is open to everyone — sign in to add, edit or delete.
          </Typography>
          <Stack spacing={2}>
            {error && <Alert severity="error">{error}</Alert>}
            <TextField
              label="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoFocus
              autoComplete="username"
              required
            />
            <TextField
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" variant="contained" disabled={busy || !username || !password}>
            {busy ? 'Signing in…' : 'Sign in'}
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  )
}
