import { useState } from 'react'
import {
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Fab,
  FormControlLabel,
  IconButton,
  MenuItem,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import { useAnimals, useCreateAnimal, useDeleteAnimal, useUpdateAnimal } from '../api/hooks'
import type { Animal } from '../api/types'
import QueryBoundary from '../components/QueryBoundary'

const SPECIES: [string, string][] = [
  ['chicken', 'Chicken'],
  ['duck', 'Duck'],
  ['goose', 'Goose'],
  ['turkey', 'Turkey'],
  ['goat', 'Goat'],
  ['sheep', 'Sheep'],
  ['pig', 'Pig'],
  ['cow', 'Cow'],
  ['horse', 'Horse'],
  ['rabbit', 'Rabbit'],
  ['tortoise', 'Tortoise'],
  ['dog', 'Dog'],
  ['cat', 'Cat'],
  ['bees', 'Bee colony'],
  ['other', 'Other'],
]

const SPECIES_EMOJI: Record<string, string> = {
  chicken: '🐔',
  duck: '🦆',
  goose: '🦢',
  turkey: '🦃',
  goat: '🐐',
  sheep: '🐑',
  pig: '🐷',
  cow: '🐄',
  horse: '🐴',
  rabbit: '🐰',
  tortoise: '🐢',
  dog: '🐕',
  cat: '🐈',
  bees: '🐝',
  other: '🐾',
}

interface SpeciesGroup {
  code: string
  label: string
  animals: Animal[]
}

function groupBySpecies(animals: Animal[]): SpeciesGroup[] {
  const map = new Map<string, SpeciesGroup>()
  for (const a of animals) {
    const group = map.get(a.species) ?? { code: a.species, label: a.species_display, animals: [] }
    group.animals.push(a)
    map.set(a.species, group)
  }
  return [...map.values()].sort((x, y) => x.label.localeCompare(y.label))
}

/** Age from date of birth, e.g. "2 yr 3 mo" / "5 mo". Null if unknown. */
function ageLabel(dob: string | null): string | null {
  if (!dob) return null
  const birth = new Date(dob)
  if (Number.isNaN(birth.getTime())) return null
  const now = new Date()
  let months = (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth())
  if (now.getDate() < birth.getDate()) months -= 1
  if (months < 0) return null
  const years = Math.floor(months / 12)
  const rem = months % 12
  if (years === 0) return `${months} mo`
  if (rem === 0) return `${years} yr`
  return `${years} yr ${rem} mo`
}

function AnimalRow({
  animal,
  onEdit,
  onDelete,
}: {
  animal: Animal
  onEdit: (a: Animal) => void
  onDelete: (a: Animal) => void
}) {
  const facts = [ageLabel(animal.date_of_birth), animal.breed].filter(Boolean).join(' · ')
  return (
    <Card sx={{ mb: 1 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, p: 1.5 }}>
        <Box
          sx={{ flex: 1, minWidth: 0, cursor: 'pointer' }}
          onClick={() => onEdit(animal)}
          role="button"
          aria-label={`Edit ${animal.name}`}
        >
          <Typography noWrap>{animal.name}</Typography>
          <Typography variant="caption" color="text.secondary">
            {facts || '—'}
          </Typography>
        </Box>
        <Chip
          size="small"
          label={animal.active ? 'Active' : 'Retired'}
          color={animal.active ? 'success' : 'default'}
          variant={animal.active ? 'filled' : 'outlined'}
        />
        <IconButton aria-label={`Remove ${animal.name}`} onClick={() => onDelete(animal)}>
          <DeleteOutlineIcon />
        </IconButton>
      </Box>
    </Card>
  )
}

function AnimalDialog({ animal, onClose }: { animal?: Animal; onClose: () => void }) {
  const editing = animal != null
  const create = useCreateAnimal()
  const update = useUpdateAnimal()
  const [name, setName] = useState(animal?.name ?? '')
  const [species, setSpecies] = useState(animal?.species ?? 'chicken')
  const [breed, setBreed] = useState(animal?.breed ?? '')
  const [active, setActive] = useState(animal?.active ?? true)
  const [error, setError] = useState<string | null>(null)

  const busy = create.isPending || update.isPending

  const save = async () => {
    if (!name.trim()) {
      setError('Enter a name.')
      return
    }
    try {
      if (editing) {
        await update.mutateAsync({
          id: animal.id,
          patch: { name: name.trim(), species, breed: breed.trim(), active },
        })
      } else {
        await create.mutateAsync({ name: name.trim(), species, breed: breed.trim() })
      }
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>{editing ? 'Edit animal' : 'New animal'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            required
          />
          <TextField
            select
            label="Species"
            value={species}
            onChange={(e) => setSpecies(e.target.value)}
          >
            {SPECIES.map(([value, label]) => (
              <MenuItem key={value} value={value}>
                {label}
              </MenuItem>
            ))}
          </TextField>
          <TextField label="Breed (optional)" value={breed} onChange={(e) => setBreed(e.target.value)} />
          {editing && (
            <FormControlLabel
              control={<Switch checked={active} onChange={(e) => setActive(e.target.checked)} />}
              label={active ? 'Active' : 'Retired'}
            />
          )}
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={busy}>
          {editing ? 'Save' : 'Add'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}

export default function AnimalsPage() {
  const animals = useAnimals()
  const del = useDeleteAnimal()
  const [selected, setSelected] = useState<string | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<Animal | null>(null)

  const confirmDelete = (a: Animal) => {
    if (window.confirm(`Remove ${a.name}? Their tasks stay but become unassigned.`)) {
      del.mutate(a.id)
    }
  }

  return (
    <Box sx={{ pb: 10 }}>
      <QueryBoundary query={animals}>
        {(list) => {
          if (list.length === 0) {
            return (
              <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
                No animals yet — add your first.
              </Typography>
            )
          }
          const groups = groupBySpecies(list)

          // Top level: a tile per species kept.
          if (selected === null) {
            return (
              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))',
                  gap: 1.5,
                }}
              >
                {groups.map((g) => (
                  <Card key={g.code}>
                    <CardActionArea onClick={() => setSelected(g.code)} sx={{ height: '100%' }}>
                      <CardContent sx={{ textAlign: 'center', py: 2 }}>
                        <Typography sx={{ fontSize: 40, lineHeight: 1 }}>
                          {SPECIES_EMOJI[g.code] ?? '🐾'}
                        </Typography>
                        <Typography variant="subtitle1" sx={{ mt: 1 }}>
                          {g.label}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          {g.animals.length} {g.animals.length === 1 ? 'animal' : 'animals'}
                        </Typography>
                      </CardContent>
                    </CardActionArea>
                  </Card>
                ))}
              </Box>
            )
          }

          // Drill-down: the individual animals of the chosen species.
          const group = groups.find((g) => g.code === selected)
          return (
            <Stack spacing={1}>
              <Stack direction="row" alignItems="center" spacing={1}>
                <IconButton onClick={() => setSelected(null)} aria-label="Back to all animals">
                  <ArrowBackIcon />
                </IconButton>
                <Typography variant="h6">{group?.label ?? 'Animals'}</Typography>
              </Stack>
              {!group || group.animals.length === 0 ? (
                <Typography color="text.secondary">None of these left.</Typography>
              ) : (
                group.animals.map((a) => (
                  <AnimalRow key={a.id} animal={a} onEdit={setEditing} onDelete={confirmDelete} />
                ))
              )}
            </Stack>
          )
        }}
      </QueryBoundary>

      <Fab
        color="primary"
        sx={{
          position: 'fixed',
          bottom: 'calc(80px + env(safe-area-inset-bottom, 0px))',
          right: 24,
          zIndex: (t) => t.zIndex.appBar + 1,
        }}
        onClick={() => setDialogOpen(true)}
        aria-label="Add animal"
      >
        <AddIcon />
      </Fab>
      {(dialogOpen || editing) && (
        <AnimalDialog
          animal={editing ?? undefined}
          onClose={() => {
            setDialogOpen(false)
            setEditing(null)
          }}
        />
      )}
    </Box>
  )
}
