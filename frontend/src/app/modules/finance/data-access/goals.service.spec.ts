import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { goalPercent, goalTargetMonthLabel, SavingsGoal } from './goals.models';
import { GoalsService } from './goals.service';

const BASE = '/api/v1/finance/goals';

function goal(overrides: Partial<SavingsGoal> = {}): SavingsGoal {
  return {
    id: 'japan',
    name: 'Viaje a Japón',
    target_cents: 450000,
    target_date: '2027-04-30',
    account_id: null,
    account: null,
    icon: 'plane',
    color: null,
    achieved: false,
    achieved_at: null,
    saved_cents: 180000,
    remaining_cents: 270000,
    progress_bp: 4000,
    months_left: 7,
    monthly_needed_cents: 38572,
    contributions_count: 3,
    created_at: null,
    updated_at: null,
    ...overrides,
  };
}

describe('goals models', () => {
  it('rounds progress down and labels the target month', () => {
    expect(goalPercent({ progress_bp: 8359 })).toBe(83);
    expect(goalTargetMonthLabel('2027-06-30')).toBe('jun 2027');
    expect(goalTargetMonthLabel(null)).toBeNull();
  });
});

describe('GoalsService', () => {
  let service: GoalsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(GoalsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('loads goals with achieved ones last', async () => {
    const loading = service.load();
    http.expectOne(BASE).flush({ data: [goal({ id: 'done', achieved: true }), goal()] });
    await loading;
    expect(service.goals().map((item) => item.id)).toEqual(['japan', 'done']);
    expect(service.activeGoals()).toHaveLength(1);
    expect(service.totalSavedCents()).toBe(360000);
  });

  it('records a contribution and refreshes the goal from the response meta', async () => {
    service.goals.set([goal()]);
    const contributing = service.contribute('japan', { amount_cents: 50000, date: '2026-10-24', note: null });
    const request = http.expectOne(`${BASE}/japan/contributions`);
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ amount_cents: 50000, date: '2026-10-24', note: null });
    request.flush({
      data: { id: 'c1', goal_id: 'japan', amount_cents: 50000, date: '2026-10-24', note: null, transaction_id: null, created_at: null },
      meta: { goal: goal({ saved_cents: 230000, progress_bp: 5111 }) },
    });
    const result = await contributing;
    expect(result.contribution.id).toBe('c1');
    expect(service.goals()[0].saved_cents).toBe(230000);
  });

  it('sorts contributions newest first', async () => {
    const loading = service.contributions('japan');
    http.expectOne(`${BASE}/japan/contributions`).flush({
      data: [
        { id: 'old', goal_id: 'japan', amount_cents: 100, date: '2026-01-01', note: null, transaction_id: null, created_at: null },
        { id: 'new', goal_id: 'japan', amount_cents: 100, date: '2026-10-01', note: null, transaction_id: null, created_at: null },
      ],
    });
    expect((await loading).map((item) => item.id)).toEqual(['new', 'old']);
  });

  it('links a goal to an account with a partial update', async () => {
    service.goals.set([goal()]);
    const updating = service.update('japan', { account_id: 'savings' });
    const request = http.expectOne(`${BASE}/japan`);
    expect(request.request.method).toBe('PATCH');
    expect(request.request.body).toEqual({ account_id: 'savings' });
    request.flush({ data: goal({ account_id: 'savings', account: { id: 'savings', name: 'Ahorro', type: 'savings' } }) });
    await updating;
    expect(service.goals()[0].account?.name).toBe('Ahorro');
  });
});
