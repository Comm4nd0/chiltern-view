import { Alert, Box, Card, CardContent, Stack, Typography } from '@mui/material'
import { CloudSun, Drop, Snowflake } from '@phosphor-icons/react'
import type { Weather, WeatherDay } from '../api/types'
import { fmtDate } from '../format'

const SKY = '#5AC8FA'

function temp(value: number | null): string {
  return value == null ? '–' : `${Math.round(value)}`
}

function DayColumn({ day }: { day: WeatherDay }) {
  return (
    <Box sx={{ flex: 1, textAlign: 'center' }}>
      <Typography variant="caption" fontWeight={600} display="block">
        {fmtDate(day.date, { weekday: 'short' })}
      </Typography>
      <Typography variant="body2">
        {temp(day.tmin)}–{temp(day.tmax)}°
      </Typography>
      <Stack direction="row" spacing={0.25} alignItems="center" justifyContent="center">
        {day.frost && <Snowflake size={12} color="#0A84FF" weight="bold" />}
        {day.precip_mm > 0 && (
          <>
            <Drop size={12} color={SKY} weight="fill" />
            <Typography variant="caption" color="text.secondary">
              {Math.round(day.precip_mm)}mm
            </Typography>
          </>
        )}
      </Stack>
    </Box>
  )
}

/** Today + the next few days at Medmenham, with frost warnings for tender crops. */
export default function WeatherCard({ weather }: { weather: Weather }) {
  const today = weather.today
  const rainBits: string[] = []
  if (today) rainBits.push(`${Math.round(today.precip_mm)} mm today`)
  if (weather.recent_rain_mm > 0) rainBits.push(`${weather.recent_rain_mm} mm last 2 days`)

  return (
    <Card>
      <CardContent>
        <Stack direction="row" alignItems="center" spacing={1.5}>
          <Box
            sx={{
              width: 38,
              height: 38,
              borderRadius: 2.5,
              bgcolor: `${SKY}1F`,
              color: SKY,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <CloudSun size={22} weight="fill" />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="subtitle1">Weather</Typography>
            <Typography variant="body2" color="text.secondary" noWrap>
              {weather.location}
              {rainBits.length > 0 && ` · ${rainBits.join(' · ')}`}
            </Typography>
          </Box>
          {today && (
            <Typography variant="h5" sx={{ fontWeight: 700 }}>
              {temp(today.tmin)}–{temp(today.tmax)}°
            </Typography>
          )}
        </Stack>

        {weather.days.length > 0 && (
          <Stack direction="row" sx={{ mt: 1.5 }}>
            {weather.days.map((day) => (
              <DayColumn key={day.date} day={day} />
            ))}
          </Stack>
        )}

        {weather.frost_warning && (
          <Alert
            severity="warning"
            icon={<Snowflake size={20} />}
            sx={{ mt: 1.5, borderRadius: 2.5 }}
          >
            {weather.frost_warning.message}
          </Alert>
        )}

        {weather.stale && (
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
            Offline — showing the last fetched forecast.
          </Typography>
        )}
      </CardContent>
    </Card>
  )
}
