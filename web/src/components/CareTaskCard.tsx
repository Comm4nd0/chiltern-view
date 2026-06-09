import { Box, Button, Card, CardContent, Stack, Typography } from '@mui/material'
import { Clock, Check } from '@phosphor-icons/react'
import type { CareTask } from '../api/types'
import { statusColor } from '../theme'
import { fmtDate } from '../format'
import AssigneeAvatar from './AssigneeAvatar'

function dueLabel(task: CareTask): string {
  if (task.status === 'due_today') return 'Due today'
  if (task.days_overdue > 0) {
    return `${task.days_overdue} day${task.days_overdue === 1 ? '' : 's'} overdue`
  }
  const inDays = -task.days_overdue
  return `Due in ${inDays} day${inDays === 1 ? '' : 's'}`
}

export default function CareTaskCard({
  task,
  onComplete,
  completing,
  onEdit,
}: {
  task: CareTask
  onComplete: () => void
  completing: boolean
  onEdit?: () => void
}) {
  const color = statusColor(task.status)
  const recurrence = task.due_date ? 'one-off' : `every ${task.recurrence_interval_days} days`
  const sub = [task.animal_name, recurrence].filter(Boolean).join(' · ')

  return (
    <Card sx={{ display: 'flex', overflow: 'hidden' }}>
      <Box sx={{ width: 6, bgcolor: color, flexShrink: 0 }} />
      <CardContent
        sx={{ flex: 1, py: 1.5, cursor: onEdit ? 'pointer' : 'default' }}
        onClick={onEdit}
        role={onEdit ? 'button' : undefined}
        aria-label={onEdit ? `Edit ${task.name}` : undefined}
      >
        <Stack direction="row" alignItems="flex-start" spacing={1}>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="subtitle1" fontWeight={600}>
              {task.name}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {sub}
            </Typography>
            <Stack direction="row" alignItems="center" spacing={0.5} sx={{ mt: 1 }}>
              <Clock size={16} weight="fill" color={color} />
              <Typography variant="body2" sx={{ color, fontWeight: 600 }}>
                {dueLabel(task)}
              </Typography>
              <Box sx={{ flex: 1 }} />
              <Typography variant="caption" color="text.secondary">
                {fmtDate(task.next_due)}
              </Typography>
            </Stack>
          </Box>
          {task.assignee_name && <AssigneeAvatar name={task.assignee_name} />}
        </Stack>
      </CardContent>
      <Box sx={{ display: 'flex', alignItems: 'center', pr: 1 }}>
        <Button
          onClick={onComplete}
          disabled={completing}
          variant="contained"
          size="small"
          startIcon={<Check size={16} weight="bold" />}
        >
          Done
        </Button>
      </Box>
    </Card>
  )
}
