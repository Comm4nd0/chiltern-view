import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import AddIcon from '@mui/icons-material/Add'
import { useCreateSupply, useDeleteSupply, useSupplies, useUpdateSupply } from '../api/hooks'
import QueryBoundary from '../components/QueryBoundary'
import type { Supply } from '../api/types'

function SupplyDialog({ supply, onClose }: { supply?: Supply; onClose: () => void }) {
  const editing = supply != null
  const create = useCreateSupply()
  const update = useUpdateSupply()
  const del = useDeleteSupply()
  const [name, setName] = useState(supply?.name ?? '')
  const [unit, setUnit] = useState(supply?.unit ?? '')
  const [quantity, setQuantity] = useState(supply?.quantity ?? '')
  const [reorderAt, setReorderAt] = useState(supply?.reorder_at ?? '')
  const [notes, setNotes] = useState(supply?.notes ?? '')
  const [error, setError] = useState<string | null>(null)
  const busy = create.isPending || update.isPending || del.isPending

  const save = async () => {
    if (!name.trim()) {
      setError('Give the supply a name.')
      return
    }
    const payload = {
      name: name.trim(),
      unit: unit.trim(),
      quantity: quantity.trim() || '0',
      reorder_at: reorderAt.trim() || '0',
      notes: notes.trim(),
    }
    try {
      if (editing) await update.mutateAsync({ id: supply.id, patch: payload })
      else await create.mutateAsync(payload)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  const remove = async () => {
    if (!editing) return
    if (!window.confirm(`Delete ${supply.name}?`)) return
    try {
      await del.mutateAsync(supply.id)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to delete.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>{editing ? 'Edit supply' : 'New supply'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField label="Name (e.g. Layer pellets)" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
          <TextField label="Unit (e.g. kg, bags, bales)" value={unit} onChange={(e) => setUnit(e.target.value)} />
          <Stack direction="row" spacing={2}>
            <TextField
              label="In stock"
              type="number"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
              fullWidth
            />
            <TextField
              label="Reorder at"
              type="number"
              value={reorderAt}
              onChange={(e) => setReorderAt(e.target.value)}
              helperText="Flag low at/below this"
              fullWidth
            />
          </Stack>
          <TextField label="Notes (optional)" value={notes} onChange={(e) => setNotes(e.target.value)} multiline minRows={2} />
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        {editing && (
          <Button color="error" onClick={remove} disabled={busy} sx={{ mr: 'auto' }}>
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

/** Feed & supply inventory: stock levels with low-stock flags. */
export default function SuppliesPage() {
  const navigate = useNavigate()
  const supplies = useSupplies()
  const [adding, setAdding] = useState(false)
  const [editing, setEditing] = useState<Supply | null>(null)

  return (
    <Stack spacing={1}>
      <Stack direction="row" alignItems="center" spacing={1}>
        <Button startIcon={<ArrowBackIcon />} onClick={() => navigate(-1)}>
          Back
        </Button>
        <Typography variant="h6" sx={{ flex: 1 }}>
          Supplies
        </Typography>
        <IconButton color="primary" onClick={() => setAdding(true)} aria-label="Add supply">
          <AddIcon />
        </IconButton>
      </Stack>

      <QueryBoundary query={supplies}>
        {(list) =>
          list.length === 0 ? (
            <Typography color="text.secondary" sx={{ py: 4, textAlign: 'center' }}>
              No supplies tracked yet — add feed, hay, bedding…
            </Typography>
          ) : (
            <Stack spacing={1}>
              {list.map((s) => (
                <Card key={s.id}>
                  <CardContent
                    sx={{ py: 1.5, cursor: 'pointer' }}
                    onClick={() => setEditing(s)}
                    role="button"
                  >
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Typography sx={{ flex: 1 }} fontWeight={600}>
                        {s.name}
                      </Typography>
                      {s.is_low && <Chip size="small" color="warning" label="Low" />}
                      <Typography variant="body2" color="text.secondary">
                        {Number(s.quantity)} {s.unit}
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              ))}
            </Stack>
          )
        }
      </QueryBoundary>

      {adding && <SupplyDialog onClose={() => setAdding(false)} />}
      {editing && <SupplyDialog supply={editing} onClose={() => setEditing(null)} />}
    </Stack>
  )
}
