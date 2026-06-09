import { useState } from 'react'
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useCreateLogEntry, useDeleteLogEntry, useUpdateLogEntry } from '../api/hooks'
import type { LogEntry } from '../api/types'
import { NOTE_TYPES } from '../journal'

/** Add a journal note for an animal, or edit/delete an existing one. */
export default function LogEntryDialog({
  animalId,
  entry,
  onClose,
}: {
  animalId: number
  entry?: LogEntry
  onClose: () => void
}) {
  const editing = entry != null
  const create = useCreateLogEntry()
  const update = useUpdateLogEntry()
  const remove = useDeleteLogEntry()
  const todayIso = new Date().toISOString().slice(0, 10)

  const [type, setType] = useState<string>(entry?.entry_type ?? 'general')
  const [note, setNote] = useState(entry?.note ?? '')
  const [occurredOn, setOccurredOn] = useState(entry?.occurred_on ?? todayIso)
  const [error, setError] = useState<string | null>(null)

  const busy = create.isPending || update.isPending || remove.isPending

  const save = async () => {
    if (!note.trim()) {
      setError('Write a note.')
      return
    }
    const payload = { entry_type: type, note: note.trim(), occurred_on: occurredOn }
    try {
      if (editing) await update.mutateAsync({ id: entry.id, patch: payload })
      else await create.mutateAsync({ ...payload, animal: animalId })
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  const del = async () => {
    if (!editing) return
    try {
      await remove.mutateAsync(entry.id)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to delete.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>{editing ? 'Edit note' : 'New note'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField select label="Type" value={type} onChange={(e) => setType(e.target.value)}>
            {NOTE_TYPES.map(([value, label]) => (
              <MenuItem key={value} value={value}>
                {label}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Note"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            multiline
            minRows={2}
            autoFocus
            required
          />
          <TextField
            label="When"
            type="date"
            value={occurredOn}
            onChange={(e) => setOccurredOn(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
          />
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        {editing && (
          <Button color="error" onClick={del} disabled={busy} sx={{ mr: 'auto' }}>
            Delete
          </Button>
        )}
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={busy}>
          {editing ? 'Save' : 'Add'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}
