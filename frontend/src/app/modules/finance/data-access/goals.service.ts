import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { firstValueFrom, map } from 'rxjs';
import { GoalContribution, GoalContributionPayload, SavingsGoal, SavingsGoalPayload, sortGoals } from './goals.models';
import { FinanceAccountLookup } from './recurring.models';
import { fetchAccountLookups, financeApiUrl } from './recurring.service';

@Injectable({ providedIn: 'root' })
export class GoalsService {
  private readonly http = inject(HttpClient);

  readonly goals = signal<SavingsGoal[]>([]);
  readonly loading = signal(false);
  readonly loaded = signal(false);
  readonly error = signal<string | null>(null);

  readonly activeGoals = computed(() => this.goals().filter((goal) => !goal.achieved));
  readonly totalSavedCents = computed(() => this.goals().reduce((sum, goal) => sum + goal.saved_cents, 0));

  async load(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const response = await firstValueFrom(this.http.get<{ data: SavingsGoal[] }>(financeApiUrl('goals')));
      this.goals.set(sortGoals(response.data));
      this.loaded.set(true);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido cargar los objetivos.'));
    } finally {
      this.loading.set(false);
    }
  }

  get(id: string): Promise<SavingsGoal> {
    return firstValueFrom(
      this.http.get<{ data: SavingsGoal }>(financeApiUrl(`goals/${id}`)).pipe(map((response) => response.data)),
    );
  }

  async create(payload: SavingsGoalPayload): Promise<SavingsGoal> {
    const response = await firstValueFrom(this.http.post<{ data: SavingsGoal }>(financeApiUrl('goals'), payload));
    this.goals.update((goals) => sortGoals([...goals, response.data]));
    return response.data;
  }

  async update(id: string, patch: Partial<SavingsGoalPayload>): Promise<SavingsGoal> {
    const response = await firstValueFrom(
      this.http.patch<{ data: SavingsGoal }>(financeApiUrl(`goals/${id}`), patch),
    );
    this.replace(response.data);
    return response.data;
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete<void>(financeApiUrl(`goals/${id}`)));
    this.goals.update((goals) => goals.filter((goal) => goal.id !== id));
  }

  contributions(goalId: string): Promise<GoalContribution[]> {
    return firstValueFrom(
      this.http
        .get<{ data: GoalContribution[] }>(financeApiUrl(`goals/${goalId}/contributions`))
        .pipe(map((response) => [...response.data].sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0)))),
    );
  }

  async contribute(goalId: string, payload: GoalContributionPayload): Promise<{ contribution: GoalContribution; goal: SavingsGoal }> {
    const response = await firstValueFrom(
      this.http.post<{ data: GoalContribution; meta: { goal: SavingsGoal } }>(
        financeApiUrl(`goals/${goalId}/contributions`),
        payload,
      ),
    );
    this.replace(response.meta.goal);
    return { contribution: response.data, goal: response.meta.goal };
  }

  async removeContribution(goalId: string, contributionId: string): Promise<void> {
    await firstValueFrom(this.http.delete<void>(financeApiUrl(`goals/${goalId}/contributions/${contributionId}`)));
  }

  accounts(): Promise<FinanceAccountLookup[]> {
    return fetchAccountLookups(this.http);
  }

  private replace(goal: SavingsGoal): void {
    this.goals.update((goals) => {
      const exists = goals.some((current) => current.id === goal.id);
      return sortGoals(exists ? goals.map((current) => (current.id === goal.id ? goal : current)) : [...goals, goal]);
    });
  }
}
