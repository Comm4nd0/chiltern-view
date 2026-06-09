import { useNavigate } from 'react-router-dom'
import {
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Chip,
  Divider,
  Stack,
  Typography,
} from '@mui/material'
import ChecklistIcon from '@mui/icons-material/Checklist'
import PetsIcon from '@mui/icons-material/Pets'
import GrassIcon from '@mui/icons-material/Grass'
import EggIcon from '@mui/icons-material/Egg'
import { useCompleteTask, useOverview } from '../api/hooks'
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

function CountPill({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <Box sx={{ flex: 1, textAlign: 'center', borderRadius: 2, py: 1, bgcolor: `${color}14` }}>
      <Typography variant="h5" sx={{ color, fontWeight: 700, lineHeight: 1.1 }}>
        {value}
      </Typography>
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
    </Box>
  )
}

export default function OverviewPage() {
  const overview = useOverview()
  const navigate = useNavigate()
  const complete = useCompleteTask()

  return (
    <QueryBoundary query={overview}>
      {(data) => (
        <Stack spacing={2}>
          {/* Needs doing */}
          <Card>
            <CardContent>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                <ChecklistIcon color="primary" />
                <Typography variant="h6" sx={{ flex: 1 }}>
                  Needs doing
                </Typography>
                <Button size="small" onClick={() => navigate('/todo')}>
                  All tasks
                </Button>
              </Stack>
              <Stack direction="row" spacing={1} sx={{ mb: 1 }}>
                <CountPill label="overdue" value={data.tasks.overdue} color={statusColor('overdue')} />
                <CountPill label="today" value={data.tasks.due_today} color={statusColor('due_today')} />
                <CountPill
                  label="upcoming"
                  value={data.tasks.upcoming}
                  color={statusColor('upcoming')}
                />
              </Stack>
              {data.tasks.top.length === 0 ? (
                <Typography color="text.secondary" variant="body2">
                  All caught up.
                </Typography>
              ) : (
                <Stack divider={<Divider />}>
                  {data.tasks.top.map((task) => (
                    <Stack
                      key={task.id}
                      direction="row"
                      alignItems="center"
                      spacing={1}
                      sx={{ py: 0.75 }}
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
                        <Typography noWrap>{task.name}</Typography>
                        <Typography variant="caption" sx={{ color: statusColor(task.status) }}>
                          {dueLabel(task)}
                        </Typography>
                      </Box>
                      {task.assignee_name && <AssigneeAvatar name={task.assignee_name} size={24} />}
                      <Button
                        size="small"
                        variant="outlined"
                        disabled={complete.isPending}
                        onClick={() => complete.mutate({ id: task.id })}
                      >
                        Done
                      </Button>
                    </Stack>
                  ))}
                </Stack>
              )}
            </CardContent>
          </Card>

          {/* Potatoes */}
          <Card>
            <CardActionArea onClick={() => navigate('/crops')}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1}>
                  <GrassIcon color="primary" />
                  <Typography variant="h6" sx={{ flex: 1 }}>
                    Crops
                  </Typography>
                  <Typography variant="h6">{data.crops.growing}</Typography>
                </Stack>
                <Typography variant="body2" color="text.secondary">
                  {data.crops.growing === 0
                    ? 'nothing growing'
                    : data.crops.next_harvest
                      ? `growing · next harvest ${data.crops.next_harvest.label} ~ ${fmtDate(
                          data.crops.next_harvest.date,
                        )}`
                      : 'growing'}
                </Typography>
              </CardContent>
            </CardActionArea>
          </Card>

          {/* Eggs */}
          <Card>
            <CardActionArea onClick={() => navigate('/animals?view=eggs')}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1}>
                  <EggIcon color="primary" />
                  <Typography variant="h6" sx={{ flex: 1 }}>
                    Eggs
                  </Typography>
                  <Typography variant="h6">{data.eggs.today}</Typography>
                </Stack>
                <Typography variant="body2" color="text.secondary">
                  today · {data.eggs.this_week} this week
                </Typography>
              </CardContent>
            </CardActionArea>
          </Card>

          {/* Animals */}
          <Card>
            <CardActionArea onClick={() => navigate('/animals')}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                  <PetsIcon color="primary" />
                  <Typography variant="h6" sx={{ flex: 1 }}>
                    Animals
                  </Typography>
                  <Typography variant="h6">{data.animals.total}</Typography>
                </Stack>
                {Object.keys(data.animals.by_species).length === 0 ? (
                  <Typography variant="body2" color="text.secondary">
                    none yet
                  </Typography>
                ) : (
                  <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', rowGap: 1 }}>
                    {Object.entries(data.animals.by_species).map(([species, count]) => (
                      <Chip key={species} label={`${species}: ${count}`} size="small" />
                    ))}
                  </Stack>
                )}
              </CardContent>
            </CardActionArea>
          </Card>
        </Stack>
      )}
    </QueryBoundary>
  )
}
