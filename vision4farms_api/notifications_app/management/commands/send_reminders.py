"""
Management command que verifica atividades e eventos de agenda
que acontecem nas próximas 24h e cria notificações de lembrete.

Uso:
    python manage.py send_reminders

Recomendação: agendar via cron a cada hora.
    0 * * * * cd /path/to/project && python vision4farms_api/manage.py send_reminders
"""
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from notifications_app.models import Notifications, NotificationPreferences


class Command(BaseCommand):
    help = 'Cria notificações de lembrete para eventos futuros (respeita preferências do utilizador)'

    def handle(self, *args, **options):
        now = timezone.now()

        created = 0
        created += self._remind_activities(now)
        created += self._remind_agenda(now)

        self.stdout.write(self.style.SUCCESS(f'{created} lembretes criados.'))

    def _get_reminder_hours(self, user_id):
        """Devolve as horas de antecedência configuradas pelo utilizador (default 24)."""
        try:
            prefs = NotificationPreferences.objects.get(user_id=user_id)
            return float(prefs.reminder_hours)
        except NotificationPreferences.DoesNotExist:
            return 24.0

    def _is_type_enabled(self, user_id, notification_type):
        """Verifica se o tipo de notificação está ativado para o utilizador."""
        try:
            prefs = NotificationPreferences.objects.get(user_id=user_id)
            field = f'notify_{notification_type}'
            return getattr(prefs, field, 1) == 1
        except NotificationPreferences.DoesNotExist:
            return True

    def _remind_activities(self, now):
        from activities.models import Activities
        from authentication.models import Users

        pending = Activities.objects.filter(
            activity_status=0,
            deleted_at__isnull=True,
            activity_date_planned__gte=now,
        )

        count = 0
        for act in pending:
            if not self._is_type_enabled(act.user_id, 'activity'):
                continue

            hours = self._get_reminder_hours(act.user_id)
            window_end = now + timedelta(hours=hours)

            if act.activity_date_planned > window_end:
                continue

            exists = Notifications.objects.filter(
                activity_id=act.activity_id,
                notification_type='activity',
                notification_title__startswith='Lembrete:',
                deleted_at__isnull=True,
            ).exists()
            if exists:
                continue

            try:
                user = Users.objects.get(user_id=act.user_id)
            except Users.DoesNotExist:
                continue

            date_str = act.activity_date_planned.strftime('%d/%m/%Y %H:%M') if act.activity_date_planned else ''
            hours_label = self._format_hours(hours)
            Notifications.objects.create(
                user=user,
                farm_id=act.farm_id,
                land_id=act.land_id,
                activity_id=act.activity_id,
                notification_type='activity',
                notification_title=f'Lembrete: {act.activity_name}',
                notification_body=f'A atividade "{act.activity_name}" está agendada para {date_str}. Faltam menos de {hours_label}.',
            )
            count += 1

        return count

    def _remind_agenda(self, now):
        from agenda.models import Agenda
        from authentication.models import Users

        pending = Agenda.objects.filter(
            agenda_status=0,
            deleted_at__isnull=True,
            agenda_date__gte=now.date(),
        )

        count = 0
        for evt in pending:
            if not self._is_type_enabled(evt.user_id, 'agenda'):
                continue

            hours = self._get_reminder_hours(evt.user_id)
            window_end = now + timedelta(hours=hours)

            if evt.agenda_date > window_end.date():
                continue

            exists = Notifications.objects.filter(
                agenda_id=evt.agenda_id,
                notification_type='agenda',
                notification_title__startswith='Lembrete:',
                deleted_at__isnull=True,
            ).exists()
            if exists:
                continue

            try:
                user = Users.objects.get(user_id=evt.user_id)
            except Users.DoesNotExist:
                continue

            time_str = ''
            if evt.agenda_time_start:
                time_str = f' às {evt.agenda_time_start.strftime("%H:%M")}'

            hours_label = self._format_hours(hours)
            Notifications.objects.create(
                user=user,
                farm_id=evt.farm_id if evt.farm_id else None,
                agenda_id=evt.agenda_id,
                notification_type='agenda',
                notification_title=f'Lembrete: {evt.agenda_title}',
                notification_body=f'O evento "{evt.agenda_title}" é em {evt.agenda_date.strftime("%d/%m/%Y")}{time_str}. Faltam menos de {hours_label}.',
            )
            count += 1

        return count

    @staticmethod
    def _format_hours(hours):
        """Formata horas num texto legível (ex: 24h, 1h, 30min)."""
        if hours >= 1:
            h = int(hours)
            m = int((hours - h) * 60)
            return f'{h}h{m:02d}min' if m else f'{h}h'
        return f'{int(hours * 60)}min'
