import { useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Alert,
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Chip,
  Divider,
  Snackbar,
  Stack,
  Typography,
} from '@mui/material'
import {
  ListChecks,
  Notebook,
  PawPrint,
  Plant,
  Egg,
  CaretRight,
  CheckCircle,
  type Icon as PhosphorIcon,
} from '@phosphor-icons/react'
import { useCompleteTask, useOverview, useUncompleteTask } from '../api/hooks'
import type { OverviewTask } from '../api/types'
import QueryBoundary from '../components/QueryBoundary'
import AssigneeAvatar from '../components/AssigneeAvatar'
import { statusColor } from '../theme'
import { fmtDate } from '../format'

function dueLabel(task: OverviewTask): string {
  if (task.status === 'due_today') return 'due today'
  if (task.days_overdue > 0) return `${task.days_overdue}d overdue`
  return `due in ${-task.days_overdue}d`
}

/** A rounded, tinted square holding an icon — the iOS Settings-row motif. */
function IconTile({ icon: Icon, color }: { icon: PhosphorIcon; color: string }) {
  return (
    <Box
      sx={{
        width: 38,
        height: 38,
        borderRadius: 2.5,
        bgcolor: `${color}1F`,
        color,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <Icon size={22} weight="fill" />
    </Box>
  )
}

function CountPill({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <Box sx={{ flex: 1, textAlign: 'center', borderRadius: 3, py: 1.25, bgcolor: `${color}14` }}>
      <Typography variant="h4" sx={{ color, fontWeight: 800, lineHeight: 1.1 }}>
        {value}
      </Typography>
      <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
        {label}
      </Typography>
    </Box>
  )
}

function SummaryCard({
  icon,
  color,
  title,
  value,
  subtitle,
  onClick,
  children,
}: {
  icon: PhosphorIcon
  color: string
  title: string
  value: string | number
  subtitle?: string
  onClick: () => void
  children?: ReactNode
}) {
  return (
    <Card>
      <CardActionArea onClick={onClick}>
        <CardContent>
          <Stack direction="row" alignItems="center" spacing={1.5}>
            <IconTile icon={icon} color={color} />
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography variant="subtitle1">{title}</Typography>
              {subtitle && (
                <Typography variant="body2" color="text.secondary" noWrap>
                  {subtitle}
                </Typography>
              )}
            </Box>
            <Typography variant="h5" sx={{ fontWeight: 700 }}>
              {value}
            </Typography>
            <CaretRight size={16} weight="bold" color="rgba(60,60,67,0.3)" />
          </Stack>
          {children}
        </CardContent>
      </CardActionArea>
    </Card>
  )
}

export default function OverviewPage() {
  const overview = useOverview()
  const navigate = useNavigate()
  const complete = useCompleteTask()
  const uncomplete = useUncompleteTask()
  const [snack, setSnack] = useState<{ msg: string; undoId: number | null } | null>(null)

  const onComplete = async (task: OverviewTask) => {
    try {
      await complete.mutateAsync({ id: task.id })
      setSnack({ msg: `Marked "${task.name}" done`, undoId: task.id })
    } catch (e) {
      setSnack({ msg: e instanceof Error ? e.message : 'Failed', undoId: null })
    }
  }

  const onUndo = async () => {
    const id = snack?.undoId
    setSnack(null)
    if (id != null) await uncomplete.mutateAsync(id)
  }

  return (
    <>
    <QueryBoundary query={overview}>
      {(data) => (
        <Stack spacing={2}>
          {/* Food-safety: medication withdrawal periods still in force. */}
          {data.withdrawals.map((w) => (
            <Alert
              key={w.id}
              severity="warning"
              onClick={() => w.animal != null && navigate(`/animals/${w.animal}`)}
              sx={{ cursor: w.animal != null ? 'pointer' : 'default' }}
            >
              Don't eat eggs/meat from {w.animal_name ?? 'a treated animal'} until{' '}
              {fmtDate(w.until)}
              {w.medicine ? ` (${w.medicine})` : ''}.
            </Alert>
          ))}

          {/* Needs doing */}
          <Card>
            <CardContent>
              <Stack direction="row" alignItems="center" spacing={1.5} sx={{ mb: 1.5 }}>
                <IconTile icon={ListChecks} color="#00796B" />
                <Typography variant="h6" sx={{ flex: 1 }}>
                  Needs doing
                </Typography>
                <Button size="small" onClick={() => navigate('/todo')}>
                  All tasks
                </Button>
              </Stack>
              <Stack direction="row" spacing={1} sx={{ mb: data.tasks.top.length ? 1.5 : 0 }}>
                <CountPill label="overdue" value={data.tasks.overdue} color={statusColor('overdue')} />
                <CountPill label="today" value={data.tasks.due_today} color={statusColor('due_today')} />
                <CountPill
                  label="upcoming"
                  value={data.tasks.upcoming}
                  color={statusColor('upcoming')}
                />
              </Stack>
              {data.tasks.top.length === 0 ? (
                <Stack direction="row" alignItems="center" spacing={1} sx={{ color: 'success.main', mt: 1 }}>
                  <CheckCircle size={20} weight="fill" />
                  <Typography variant="body2" color="text.secondary">
                    All caught up.
                  </Typography>
                </Stack>
              ) : (
                <Stack divider={<Divider />}>
                  {data.tasks.top.map((task) => (
                    <Stack
                      key={task.id}
                      direction="row"
                      alignItems="center"
                      spacing={1}
                      sx={{ py: 1 }}
                    >
                      <Box
                        sx={{
                          width: 8,
                          height: 8,
                          borderRadius: '50%',
                          bgcolor: statusColor(task.status),
                          flexShrink: 0,
                        }}
                      />
                      <Box sx={{ flex: 1, minWidth: 0 }}>
                        <Typography noWrap fontWeight={500}>
                          {task.name}
                        </Typography>
                        <Typography
                          variant="caption"
                          sx={{
                            color: task.rain_deferred ? '#0A84FF' : statusColor(task.status),
                            fontWeight: 600,
                          }}
                        >
                          {task.rain_deferred ? (task.weather_note ?? 'rain — deferred') : dueLabel(task)}
                        </Typography>
                      </Box>
                      {task.assignee_name && <AssigneeAvatar name={task.assignee_name} size={24} />}
                      <Button
                        size="small"
                        variant="outlined"
                        disabled={complete.isPending}
                        onClick={() => onComplete(task)}
                      >
                        Done
                      </Button>
                    </Stack>
                  ))}
                </Stack>
              )}
            </CardContent>
          </Card>

          <SummaryCard
            icon={Plant}
            color="#34C759"
            title="Crops"
            value={data.crops.growing}
            onClick={() => navigate('/crops')}
            subtitle={
              data.crops.growing === 0
                ? 'nothing growing'
                : data.crops.next_harvest
                  ? `next harvest ${data.crops.next_harvest.label} ~ ${fmtDate(
                      data.crops.next_harvest.date,
                    )}`
                  : 'growing'
            }
          />

          <SummaryCard
            icon={Egg}
            color="#FF9500"
            title="Eggs"
            value={data.eggs.today}
            subtitle={`today · ${data.eggs.this_week} this week`}
            onClick={() => navigate('/eggs')}
          />

          <SummaryCard
            icon={PawPrint}
            color="#007AFF"
            title="Animals"
            value={data.animals.total}
            subtitle={Object.keys(data.animals.by_species).length === 0 ? 'none yet' : undefined}
            onClick={() => navigate('/animals')}
          >
            {Object.keys(data.animals.by_species).length > 0 && (
              <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', rowGap: 1, mt: 1.5 }}>
                {Object.entries(data.animals.by_species).map(([species, count]) => (
                  <Chip key={species} label={`${species}: ${count}`} size="small" />
                ))}
              </Stack>
            )}
          </SummaryCard>

          {/* The latest hand-written journal notes (task completions excluded). */}
          {data.activity.length > 0 && (
            <Card>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1.5} sx={{ mb: 0.5 }}>
                  <IconTile icon={Notebook} color="#AF52DE" />
                  <Typography variant="h6" sx={{ flex: 1 }}>
                    Recent notes
                  </Typography>
                  <Button size="small" onClick={() => navigate('/activity')}>
                    See all
                  </Button>
                </Stack>
                <Stack divider={<Divider />}>
                  {data.activity.map((entry) => (
                    <Box
                      key={entry.id}
                      sx={{ py: 1, cursor: entry.animal != null ? 'pointer' : 'default' }}
                      onClick={() =>
                        entry.animal != null && navigate(`/animals/${entry.animal}`)
                      }
                    >
                      <Typography variant="body2" noWrap>
                        {entry.note}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {[entry.animal_name, fmtDate(entry.occurred_on), entry.created_by_name]
                          .filter(Boolean)
                          .join(' · ')}
                      </Typography>
                    </Box>
                  ))}
                </Stack>
              </CardContent>
            </Card>
          )}
        </Stack>
      )}
    </QueryBoundary>
    <Snackbar
      open={snack != null}
      autoHideDuration={5000}
      onClose={() => setSnack(null)}
      message={snack?.msg ?? ''}
      action={
        snack?.undoId != null ? (
          <Button color="primary" size="small" onClick={onUndo}>
            Undo
          </Button>
        ) : undefined
      }
    />
    </>
  )
}
