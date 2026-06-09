import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Divider,
  IconButton,
  Stack,
  Typography,
} from '@mui/material'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import { useAnimalLog, useAnimals } from '../api/hooks'
import type { LogEntry } from '../api/types'
import QueryBoundary from '../components/QueryBoundary'
import AnimalDialog from '../components/AnimalDialog'
import LogEntryDialog from '../components/LogEntryDialog'
import { SPECIES_EMOJI, ageLabel } from '../animals'
import { TYPE_COLORS } from '../journal'
import { fmtDate } from '../format'

/** Chip filters over the journal. "Notes" hides routine task completions. */
const FILTERS: { key: string; label: string; types?: string }[] = [
  { key: 'notes', label: 'Notes', types: 'general,health,feeding,breeding' },
  { key: 'health', label: 'Health', types: 'health' },
  { key: 'feeding', label: 'Feeding', types: 'feeding' },
  { key: 'breeding', label: 'Breeding', types: 'breeding' },
  { key: 'all', label: 'Everything' },
]

function EntryRow({ entry, onEdit }: { entry: LogEntry; onEdit?: () => void }) {
  const color = TYPE_COLORS[entry.entry_type] ?? '#8E8E93'
  const meta = [fmtDate(entry.occurred_on), entry.created_by_name].filter(Boolean).join(' · ')
  return (
    <Stack
      direction="row"
      spacing={1.5}
      sx={{ py: 1.25, cursor: onEdit ? 'pointer' : 'default', alignItems: 'flex-start' }}
      onClick={onEdit}
      role={onEdit ? 'button' : undefined}
      aria-label={onEdit ? 'Edit note' : undefined}
    >
      <Chip
        label={entry.entry_type_display}
        size="small"
        sx={{ bgcolor: `${color}14`, color, fontWeight: 600, flexShrink: 0 }}
      />
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
          {entry.note}
        </Typography>
        <Typography variant="caption" color="text.secondary">
          {meta}
        </Typography>
      </Box>
    </Stack>
  )
}

export default function AnimalDetailPage() {
  const { id } = useParams()
  const animalId = Number(id)
  const navigate = useNavigate()
  const animals = useAnimals()
  const [filter, setFilter] = useState('notes')
  const types = FILTERS.find((f) => f.key === filter)?.types
  const log = useAnimalLog(animalId, types)
  const [addingNote, setAddingNote] = useState(false)
  const [editingNote, setEditingNote] = useState<LogEntry | null>(null)
  const [editingAnimal, setEditingAnimal] = useState(false)

  const entries = log.data?.pages.flatMap((p) => p.results) ?? []

  return (
    <QueryBoundary query={animals}>
      {(list) => {
        const animal = list.find((a) => a.id === animalId)
        if (!animal) {
          return (
            <Stack spacing={2} alignItems="flex-start">
              <Button startIcon={<ArrowBackIcon />} onClick={() => navigate('/animals')}>
                Animals
              </Button>
              <Typography color="text.secondary">That animal isn't here any more.</Typography>
            </Stack>
          )
        }
        const facts = [
          animal.species_display,
          animal.breed,
          ageLabel(animal.date_of_birth),
        ]
          .filter(Boolean)
          .join(' · ')
        return (
          <Stack spacing={2}>
            <Card>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1.5}>
                  <IconButton onClick={() => navigate('/animals')} aria-label="Back to animals">
                    <ArrowBackIcon />
                  </IconButton>
                  <Typography sx={{ fontSize: 36, lineHeight: 1 }}>
                    {SPECIES_EMOJI[animal.species] ?? '🐾'}
                  </Typography>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography variant="h6" noWrap>
                      {animal.name}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" noWrap>
                      {facts}
                    </Typography>
                  </Box>
                  <Chip
                    size="small"
                    label={animal.active ? 'Active' : 'Retired'}
                    color={animal.active ? 'success' : 'default'}
                    variant={animal.active ? 'filled' : 'outlined'}
                  />
                  <Button size="small" onClick={() => setEditingAnimal(true)}>
                    Edit
                  </Button>
                </Stack>
              </CardContent>
            </Card>

            <Card>
              <CardContent>
                <Stack direction="row" alignItems="center" sx={{ mb: 1 }}>
                  <Typography variant="h6" sx={{ flex: 1 }}>
                    Journal
                  </Typography>
                  <Button size="small" variant="contained" onClick={() => setAddingNote(true)}>
                    Add note
                  </Button>
                </Stack>
                <Stack direction="row" spacing={1} sx={{ overflowX: 'auto', pb: 1 }}>
                  {FILTERS.map((f) => (
                    <Chip
                      key={f.key}
                      label={f.label}
                      color={filter === f.key ? 'primary' : 'default'}
                      variant={filter === f.key ? 'filled' : 'outlined'}
                      onClick={() => setFilter(f.key)}
                    />
                  ))}
                </Stack>
                {log.isPending ? (
                  <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                    <CircularProgress size={28} />
                  </Box>
                ) : log.isError ? (
                  <Alert
                    severity="error"
                    action={
                      <Button size="small" onClick={() => log.refetch()}>
                        Retry
                      </Button>
                    }
                  >
                    Couldn't load the journal.
                  </Alert>
                ) : entries.length === 0 ? (
                  <Typography color="text.secondary" sx={{ py: 3, textAlign: 'center' }}>
                    Nothing in the journal yet — add the first note.
                  </Typography>
                ) : (
                  <>
                    <Stack divider={<Divider />}>
                      {entries.map((entry) => (
                        <EntryRow
                          key={entry.id}
                          entry={entry}
                          onEdit={
                            entry.entry_type === 'task_completed'
                              ? undefined
                              : () => setEditingNote(entry)
                          }
                        />
                      ))}
                    </Stack>
                    {log.hasNextPage && (
                      <Box sx={{ textAlign: 'center', mt: 1 }}>
                        <Button
                          size="small"
                          onClick={() => log.fetchNextPage()}
                          disabled={log.isFetchingNextPage}
                        >
                          {log.isFetchingNextPage ? 'Loading…' : 'Load more'}
                        </Button>
                      </Box>
                    )}
                  </>
                )}
              </CardContent>
            </Card>

            {editingAnimal && (
              <AnimalDialog animal={animal} onClose={() => setEditingAnimal(false)} />
            )}
            {(addingNote || editingNote) && (
              <LogEntryDialog
                animalId={animal.id}
                entry={editingNote ?? undefined}
                onClose={() => {
                  setAddingNote(false)
                  setEditingNote(null)
                }}
              />
            )}
          </Stack>
        )
      }}
    </QueryBoundary>
  )
}
