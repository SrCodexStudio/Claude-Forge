# Forge Library: React Modern UI

> Reference knowledge for building modern React applications with TypeScript
> Read BEFORE writing React components, state management, or UI patterns

---

## React 19+ Patterns

### Server vs Client Components

Server Components are the default in React 19 with Next.js App Router. They run on the server, have zero bundle cost, and can directly access databases or filesystems.

```tsx
// app/products/page.tsx -- Server Component (default, no directive needed)
import { db } from '@/lib/database';
import { ProductGrid } from '@/components/product-grid';

interface Product {
  id: string;
  name: string;
  price: number;
  imageUrl: string;
  category: string;
}

export default async function ProductsPage() {
  const products: Product[] = await db.product.findMany({
    where: { status: 'active' },
    orderBy: { createdAt: 'desc' },
  });

  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">Products</h1>
      <ProductGrid products={products} />
    </main>
  );
}
```

Client Components require the `'use client'` directive. Use them only when you need interactivity, browser APIs, or React state/effects.

```tsx
// components/product-grid.tsx
'use client';

import { useState, useTransition } from 'react';
import type { Product } from '@/types';

interface ProductGridProps {
  products: Product[];
}

export function ProductGrid({ products }: ProductGridProps) {
  const [filter, setFilter] = useState('');
  const [isPending, startTransition] = useTransition();

  const filtered = products.filter((p) =>
    p.name.toLowerCase().includes(filter.toLowerCase())
  );

  return (
    <div>
      <input
        type="search"
        placeholder="Filter products..."
        value={filter}
        onChange={(e) => {
          startTransition(() => setFilter(e.target.value));
        }}
        className="w-full rounded-lg border border-zinc-700 bg-zinc-900 px-4 py-2 text-white"
      />
      <div className={`grid grid-cols-3 gap-6 mt-6 ${isPending ? 'opacity-60' : ''}`}>
        {filtered.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
    </div>
  );
}
```

### use() Hook

React 19 introduces `use()` to read promises and context inside render, including conditionally.

```tsx
import { use, Suspense } from 'react';

interface UserProfile {
  id: string;
  name: string;
  avatarUrl: string;
  bio: string;
}

function UserCard({ userPromise }: { userPromise: Promise<UserProfile> }) {
  const user = use(userPromise);

  return (
    <div className="flex items-center gap-4 rounded-xl border border-zinc-800 p-4">
      <img src={user.avatarUrl} alt={user.name} className="h-12 w-12 rounded-full" />
      <div>
        <h3 className="font-semibold text-white">{user.name}</h3>
        <p className="text-sm text-zinc-400">{user.bio}</p>
      </div>
    </div>
  );
}

// Parent passes the promise, Suspense handles loading
export default function ProfilePage() {
  const userPromise = fetchUserProfile(); // starts immediately, no await

  return (
    <Suspense fallback={<ProfileSkeleton />}>
      <UserCard userPromise={userPromise} />
    </Suspense>
  );
}
```

### useActionState

Manages form state and pending status for server actions.

```tsx
'use client';

import { useActionState } from 'react';
import { createInvoice } from '@/actions/invoices';

interface ActionResult {
  success: boolean;
  message: string;
  errors?: Record<string, string[]>;
}

const initialState: ActionResult = { success: false, message: '' };

export function CreateInvoiceForm() {
  const [state, formAction, isPending] = useActionState(createInvoice, initialState);

  return (
    <form action={formAction} className="space-y-4">
      <div>
        <label htmlFor="client" className="block text-sm font-medium text-zinc-300">
          Client
        </label>
        <input
          id="client"
          name="client"
          required
          className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2"
        />
        {state.errors?.client && (
          <p className="mt-1 text-sm text-red-400">{state.errors.client[0]}</p>
        )}
      </div>
      <button
        type="submit"
        disabled={isPending}
        className="rounded-lg bg-blue-600 px-4 py-2 font-medium text-white hover:bg-blue-700 disabled:opacity-50"
      >
        {isPending ? 'Creating...' : 'Create Invoice'}
      </button>
      {state.message && (
        <p className={state.success ? 'text-green-400' : 'text-red-400'}>
          {state.message}
        </p>
      )}
    </form>
  );
}
```

### useOptimistic

Show optimistic UI updates before server confirmation.

```tsx
'use client';

import { useOptimistic } from 'react';
import { toggleLike } from '@/actions/posts';

interface Post {
  id: string;
  title: string;
  likeCount: number;
  isLiked: boolean;
}

export function LikeButton({ post }: { post: Post }) {
  const [optimistic, setOptimistic] = useOptimistic(
    { likeCount: post.likeCount, isLiked: post.isLiked },
    (current, _action: 'toggle') => ({
      likeCount: current.isLiked ? current.likeCount - 1 : current.likeCount + 1,
      isLiked: !current.isLiked,
    })
  );

  async function handleToggle() {
    setOptimistic('toggle');
    await toggleLike(post.id);
  }

  return (
    <button onClick={handleToggle} className="flex items-center gap-2 text-sm">
      <HeartIcon filled={optimistic.isLiked} />
      <span>{optimistic.likeCount}</span>
    </button>
  );
}
```

### useFormStatus

Access parent form submission state from nested components.

```tsx
'use client';

import { useFormStatus } from 'react-dom';

function SubmitButton({ label = 'Submit' }: { label?: string }) {
  const { pending, data, method } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-blue-600 px-4 py-2 font-medium text-white disabled:opacity-50"
    >
      {pending ? 'Submitting...' : label}
    </button>
  );
}
```

### ref as Prop (No forwardRef)

React 19 passes ref as a regular prop. No more `forwardRef` wrapper.

```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  ref?: React.Ref<HTMLInputElement>;
}

function TextInput({ label, error, ref, className, ...props }: InputProps) {
  return (
    <div>
      <label className="block text-sm font-medium text-zinc-300">{label}</label>
      <input
        ref={ref}
        className={`mt-1 w-full rounded-lg border bg-zinc-900 px-3 py-2 ${
          error ? 'border-red-500' : 'border-zinc-700'
        } ${className ?? ''}`}
        {...props}
      />
      {error && <p className="mt-1 text-sm text-red-400">{error}</p>}
    </div>
  );
}
```

### Document Metadata

React 19 hoists `<title>`, `<meta>`, and `<link>` from any component to `<head>`.

```tsx
export default function SettingsPage() {
  return (
    <>
      <title>Account Settings</title>
      <meta name="description" content="Manage your account preferences and security" />
      <section className="max-w-2xl mx-auto py-8">
        <h1 className="text-2xl font-bold">Settings</h1>
        {/* page content */}
      </section>
    </>
  );
}
```

---

## Server Components

### Async Data Fetching

Server Components can be async functions that fetch data directly.

```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react';
import { auth } from '@/lib/auth';
import { db } from '@/lib/database';
import { RevenueChart } from '@/components/charts/revenue-chart';
import { RecentOrders } from '@/components/orders/recent-orders';

interface DashboardMetrics {
  totalRevenue: number;
  activeUsers: number;
  conversionRate: number;
  pendingOrders: number;
}

async function fetchMetrics(userId: string): Promise<DashboardMetrics> {
  const [revenue, users, conversions, orders] = await Promise.all([
    db.order.aggregate({ _sum: { total: true }, where: { userId } }),
    db.user.count({ where: { lastActiveAt: { gte: thirtyDaysAgo() } } }),
    db.analytics.findFirst({ where: { metric: 'conversion_rate' } }),
    db.order.count({ where: { status: 'pending', userId } }),
  ]);

  return {
    totalRevenue: revenue._sum.total ?? 0,
    activeUsers: users,
    conversionRate: conversions?.value ?? 0,
    pendingOrders: orders,
  };
}

export default async function DashboardPage() {
  const session = await auth();
  if (!session?.user) redirect('/login');

  const metrics = await fetchMetrics(session.user.id);

  return (
    <div className="grid grid-cols-4 gap-6">
      <MetricCard label="Revenue" value={`$${metrics.totalRevenue.toLocaleString()}`} />
      <MetricCard label="Active Users" value={metrics.activeUsers.toString()} />
      <MetricCard label="Conversion" value={`${metrics.conversionRate}%`} />
      <MetricCard label="Pending Orders" value={metrics.pendingOrders.toString()} />

      <div className="col-span-3">
        <Suspense fallback={<ChartSkeleton />}>
          <RevenueChart userId={session.user.id} />
        </Suspense>
      </div>
      <div className="col-span-1">
        <Suspense fallback={<OrdersSkeleton />}>
          <RecentOrders userId={session.user.id} />
        </Suspense>
      </div>
    </div>
  );
}
```

### Passing Data to Client Components

Server components fetch data, client components handle interactivity. Pass serializable props.

```tsx
// app/projects/page.tsx (Server)
import { db } from '@/lib/database';
import { ProjectList } from '@/components/project-list'; // Client

export default async function ProjectsPage() {
  const projects = await db.project.findMany({
    select: { id: true, name: true, status: true, updatedAt: true },
    orderBy: { updatedAt: 'desc' },
  });

  // Serialize dates -- Client Components receive plain objects
  const serialized = projects.map((p) => ({
    ...p,
    updatedAt: p.updatedAt.toISOString(),
  }));

  return <ProjectList initialProjects={serialized} />;
}
```

### Server-Only Package

Prevent accidental import of server code in client bundles.

```tsx
// lib/database.ts
import 'server-only';
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient | undefined };
export const db = globalForPrisma.prisma ?? new PrismaClient();
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = db;
```

---

## Server Actions

### Complete CRUD with Validation

```tsx
// actions/projects.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { z } from 'zod';
import { auth } from '@/lib/auth';
import { db } from '@/lib/database';

const ProjectSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters').max(100),
  description: z.string().max(500).optional(),
  status: z.enum(['active', 'paused', 'archived']).default('active'),
});

interface ActionState {
  success: boolean;
  message: string;
  errors?: Record<string, string[]>;
}

export async function createProject(
  prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const session = await auth();
  if (!session?.user) return { success: false, message: 'Unauthorized' };

  const parsed = ProjectSchema.safeParse({
    name: formData.get('name'),
    description: formData.get('description'),
    status: formData.get('status'),
  });

  if (!parsed.success) {
    return {
      success: false,
      message: 'Validation failed',
      errors: parsed.error.flatten().fieldErrors,
    };
  }

  try {
    await db.project.create({
      data: { ...parsed.data, userId: session.user.id },
    });
  } catch (error) {
    return { success: false, message: 'Failed to create project' };
  }

  revalidatePath('/projects');
  redirect('/projects');
}

export async function updateProject(
  projectId: string,
  prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const session = await auth();
  if (!session?.user) return { success: false, message: 'Unauthorized' };

  const project = await db.project.findUnique({ where: { id: projectId } });
  if (!project || project.userId !== session.user.id) {
    return { success: false, message: 'Not found' };
  }

  const parsed = ProjectSchema.partial().safeParse({
    name: formData.get('name') || undefined,
    description: formData.get('description') || undefined,
    status: formData.get('status') || undefined,
  });

  if (!parsed.success) {
    return { success: false, message: 'Validation failed', errors: parsed.error.flatten().fieldErrors };
  }

  await db.project.update({ where: { id: projectId }, data: parsed.data });
  revalidatePath('/projects');
  return { success: true, message: 'Project updated' };
}

export async function deleteProject(projectId: string): Promise<ActionState> {
  const session = await auth();
  if (!session?.user) return { success: false, message: 'Unauthorized' };

  const project = await db.project.findUnique({ where: { id: projectId } });
  if (!project || project.userId !== session.user.id) {
    return { success: false, message: 'Not found' };
  }

  await db.project.delete({ where: { id: projectId } });
  revalidatePath('/projects');
  return { success: true, message: 'Project deleted' };
}
```

---

## Hooks Deep Dive

### useState with Lazy Initializers

Lazy initializers run only on mount -- useful for expensive computations.

```tsx
function EditorPanel({ documentId }: { documentId: string }) {
  // Expensive: parses stored JSON only once on mount
  const [content, setContent] = useState<EditorContent>(() => {
    const stored = localStorage.getItem(`draft-${documentId}`);
    return stored ? JSON.parse(stored) : { blocks: [], version: 1 };
  });

  return <Editor content={content} onChange={setContent} />;
}
```

### useEffect Patterns

```tsx
// Cleanup pattern -- prevent stale closures and memory leaks
function useWebSocket(url: string, onMessage: (data: unknown) => void) {
  useEffect(() => {
    const ws = new WebSocket(url);
    ws.onmessage = (event) => onMessage(JSON.parse(event.data));
    ws.onerror = (error) => console.error('WebSocket error:', error);

    return () => {
      ws.close();
    };
  }, [url]); // onMessage intentionally omitted if stable via useCallback
}

// Common mistake: infinite loop from object/array deps
// BAD: useEffect(() => { ... }, [{ id: 1 }]) -- new object each render
// GOOD: useEffect(() => { ... }, [id]) -- primitive value is stable
```

### useMemo and useCallback

```tsx
interface DataTableProps {
  rows: DataRow[];
  sortKey: string;
  filterText: string;
}

function DataTable({ rows, sortKey, filterText }: DataTableProps) {
  // useMemo: expensive computation that depends on specific values
  const processedRows = useMemo(() => {
    const filtered = rows.filter((r) =>
      r.name.toLowerCase().includes(filterText.toLowerCase())
    );
    return filtered.sort((a, b) => {
      const aVal = a[sortKey as keyof DataRow];
      const bVal = b[sortKey as keyof DataRow];
      return String(aVal).localeCompare(String(bVal));
    });
  }, [rows, sortKey, filterText]);

  // useCallback: stable reference for child component props
  const handleRowClick = useCallback((rowId: string) => {
    router.push(`/details/${rowId}`);
  }, []);

  return <VirtualizedList items={processedRows} onItemClick={handleRowClick} />;
}

// When NOT to useMemo: simple lookups, cheap computations, primitive transforms
// const fullName = useMemo(() => `${first} ${last}`, [first, last]); // overkill
```

### useTransition

```tsx
function SearchResults() {
  const [query, setQuery] = useState('');
  const [isPending, startTransition] = useTransition();
  const [results, setResults] = useState<SearchResult[]>([]);

  function handleSearch(term: string) {
    setQuery(term); // urgent: update input immediately
    startTransition(async () => {
      const data = await searchAPI(term); // non-urgent: can be interrupted
      setResults(data);
    });
  }

  return (
    <div>
      <input value={query} onChange={(e) => handleSearch(e.target.value)} />
      {isPending && <Spinner className="absolute right-3 top-3" />}
      <ResultsList results={results} />
    </div>
  );
}
```

### Custom Hook: useDebounce

```tsx
function useDebounce<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debounced;
}

// Usage
function SearchInput() {
  const [query, setQuery] = useState('');
  const debouncedQuery = useDebounce(query, 300);

  useEffect(() => {
    if (debouncedQuery) fetchResults(debouncedQuery);
  }, [debouncedQuery]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

### Custom Hook: useLocalStorage

```tsx
function useLocalStorage<T>(key: string, initialValue: T) {
  const [stored, setStored] = useState<T>(() => {
    if (typeof window === 'undefined') return initialValue;
    try {
      const item = window.localStorage.getItem(key);
      return item ? (JSON.parse(item) as T) : initialValue;
    } catch {
      return initialValue;
    }
  });

  const setValue = useCallback(
    (value: T | ((prev: T) => T)) => {
      setStored((prev) => {
        const next = value instanceof Function ? value(prev) : value;
        window.localStorage.setItem(key, JSON.stringify(next));
        return next;
      });
    },
    [key]
  );

  return [stored, setValue] as const;
}
```

### Custom Hook: useMediaQuery

```tsx
function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia(query).matches;
  });

  useEffect(() => {
    const mql = window.matchMedia(query);
    const handler = (e: MediaQueryListEvent) => setMatches(e.matches);
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, [query]);

  return matches;
}

// Usage
function ResponsiveLayout({ children }: { children: React.ReactNode }) {
  const isMobile = useMediaQuery('(max-width: 768px)');
  return isMobile ? <MobileLayout>{children}</MobileLayout> : <DesktopLayout>{children}</DesktopLayout>;
}
```

---

## Zustand State Management

### TypeScript Store with Slices

```tsx
import { create } from 'zustand';
import { persist, devtools } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

// Types
interface Notification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  read: boolean;
  createdAt: string;
}

interface NotificationSlice {
  notifications: Notification[];
  unreadCount: number;
  addNotification: (n: Omit<Notification, 'id' | 'read' | 'createdAt'>) => void;
  markAsRead: (id: string) => void;
  markAllRead: () => void;
  removeNotification: (id: string) => void;
  clearAll: () => void;
}

interface AuthSlice {
  user: { id: string; name: string; email: string; role: string } | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

type AppStore = NotificationSlice & AuthSlice;

export const useAppStore = create<AppStore>()(
  devtools(
    persist(
      immer((set, get) => ({
        // -- Notification Slice --
        notifications: [],
        unreadCount: 0,

        addNotification: (n) =>
          set((state) => {
            const notification: Notification = {
              ...n,
              id: crypto.randomUUID(),
              read: false,
              createdAt: new Date().toISOString(),
            };
            state.notifications.unshift(notification);
            state.unreadCount += 1;
          }),

        markAsRead: (id) =>
          set((state) => {
            const item = state.notifications.find((n) => n.id === id);
            if (item && !item.read) {
              item.read = true;
              state.unreadCount = Math.max(0, state.unreadCount - 1);
            }
          }),

        markAllRead: () =>
          set((state) => {
            state.notifications.forEach((n) => { n.read = true; });
            state.unreadCount = 0;
          }),

        removeNotification: (id) =>
          set((state) => {
            const idx = state.notifications.findIndex((n) => n.id === id);
            if (idx !== -1) {
              if (!state.notifications[idx].read) state.unreadCount -= 1;
              state.notifications.splice(idx, 1);
            }
          }),

        clearAll: () => set((state) => { state.notifications = []; state.unreadCount = 0; }),

        // -- Auth Slice --
        user: null,
        token: null,
        isAuthenticated: false,

        login: async (email, password) => {
          const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password }),
          });
          if (!res.ok) throw new Error('Login failed');
          const { user, token } = await res.json();
          set({ user, token, isAuthenticated: true });
        },

        logout: () => set({ user: null, token: null, isAuthenticated: false }),
      })),
      {
        name: 'app-store',
        partialize: (state) => ({ token: state.token, user: state.user }),
      }
    )
  )
);

// Selectors -- avoid re-renders by selecting only what you need
export const useUnreadCount = () => useAppStore((s) => s.unreadCount);
export const useCurrentUser = () => useAppStore((s) => s.user);
export const useIsAuthenticated = () => useAppStore((s) => s.isAuthenticated);
```

---

## TanStack Query

### Key Factories and Typed Queries

```tsx
import {
  useQuery,
  useMutation,
  useQueryClient,
  useInfiniteQuery,
  type QueryFunctionContext,
} from '@tanstack/react-query';

// Key factory -- centralizes all query keys for consistency
export const projectKeys = {
  all: ['projects'] as const,
  lists: () => [...projectKeys.all, 'list'] as const,
  list: (filters: ProjectFilters) => [...projectKeys.lists(), filters] as const,
  details: () => [...projectKeys.all, 'detail'] as const,
  detail: (id: string) => [...projectKeys.details(), id] as const,
  members: (id: string) => [...projectKeys.detail(id), 'members'] as const,
};

interface Project {
  id: string;
  name: string;
  description: string;
  status: 'active' | 'paused' | 'archived';
  createdAt: string;
  memberCount: number;
}

interface ProjectFilters {
  status?: string;
  search?: string;
}

// Typed fetch function
async function fetchProjects(filters: ProjectFilters): Promise<Project[]> {
  const params = new URLSearchParams();
  if (filters.status) params.set('status', filters.status);
  if (filters.search) params.set('search', filters.search);

  const res = await fetch(`/api/projects?${params}`);
  if (!res.ok) throw new Error('Failed to fetch projects');
  return res.json();
}

// useQuery with full typing
export function useProjects(filters: ProjectFilters = {}) {
  return useQuery({
    queryKey: projectKeys.list(filters),
    queryFn: () => fetchProjects(filters),
    staleTime: 5 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
  });
}

export function useProject(id: string) {
  return useQuery({
    queryKey: projectKeys.detail(id),
    queryFn: async () => {
      const res = await fetch(`/api/projects/${id}`);
      if (!res.ok) throw new Error('Project not found');
      return res.json() as Promise<Project>;
    },
    enabled: !!id,
  });
}
```

### Mutations with Optimistic Updates

```tsx
interface CreateProjectInput {
  name: string;
  description: string;
}

export function useCreateProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: CreateProjectInput) => {
      const res = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(input),
      });
      if (!res.ok) throw new Error('Failed to create project');
      return res.json() as Promise<Project>;
    },

    onMutate: async (newProject) => {
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });

      const previous = queryClient.getQueryData<Project[]>(projectKeys.lists());

      queryClient.setQueryData<Project[]>(projectKeys.lists(), (old = []) => [
        {
          ...newProject,
          id: `temp-${Date.now()}`,
          status: 'active' as const,
          createdAt: new Date().toISOString(),
          memberCount: 1,
        },
        ...old,
      ]);

      return { previous };
    },

    onError: (_err, _input, context) => {
      if (context?.previous) {
        queryClient.setQueryData(projectKeys.lists(), context.previous);
      }
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}
```

### Infinite Query for Pagination

```tsx
interface PaginatedResponse<T> {
  items: T[];
  nextCursor: string | null;
  totalCount: number;
}

export function useInfiniteProjects(filters: ProjectFilters = {}) {
  return useInfiniteQuery({
    queryKey: [...projectKeys.list(filters), 'infinite'],
    queryFn: async ({ pageParam }: QueryFunctionContext & { pageParam: string | undefined }) => {
      const params = new URLSearchParams();
      if (pageParam) params.set('cursor', pageParam);
      if (filters.status) params.set('status', filters.status);

      const res = await fetch(`/api/projects?${params}`);
      return res.json() as Promise<PaginatedResponse<Project>>;
    },
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
  });
}

// Usage
function InfiniteProjectList() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteProjects();

  const allProjects = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <div>
      {allProjects.map((project) => (
        <ProjectRow key={project.id} project={project} />
      ))}
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

### Prefetching

```tsx
// Prefetch on hover for instant navigation
function ProjectLink({ project }: { project: Project }) {
  const queryClient = useQueryClient();

  function handleMouseEnter() {
    queryClient.prefetchQuery({
      queryKey: projectKeys.detail(project.id),
      queryFn: () => fetch(`/api/projects/${project.id}`).then((r) => r.json()),
      staleTime: 60 * 1000,
    });
  }

  return (
    <Link href={`/projects/${project.id}`} onMouseEnter={handleMouseEnter}>
      {project.name}
    </Link>
  );
}
```

---

## Tailwind CSS 4

### @theme Directive

Tailwind v4 replaces `tailwind.config.js` with CSS-first configuration.

```css
/* app/globals.css */
@import 'tailwindcss';

@theme {
  --color-background: #09090b;
  --color-surface: #111113;
  --color-surface-elevated: #1a1a1c;
  --color-border: #27272a;
  --color-border-hover: #3f3f46;
  --color-accent: #3b82f6;
  --color-accent-hover: #2563eb;
  --color-text-primary: #fafafa;
  --color-text-secondary: rgba(250, 250, 250, 0.7);
  --color-text-muted: rgba(250, 250, 250, 0.5);
  --color-text-disabled: rgba(250, 250, 250, 0.3);

  --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;

  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 8px;

  --animate-fade-in: fade-in 300ms ease-out;
  --animate-slide-up: slide-up 300ms ease-out;
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slide-up {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
```

### Container Queries

```tsx
function WidgetCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="@container rounded-lg border border-border bg-surface p-4">
      <h3 className="text-sm font-medium text-text-secondary">{title}</h3>
      <div className="mt-2 @sm:flex @sm:items-center @sm:gap-4 @lg:grid @lg:grid-cols-2">
        {children}
      </div>
    </div>
  );
}
```

### Responsive and Dark Mode Patterns

```tsx
function PageLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background text-text-primary">
      <nav className="sticky top-0 z-40 border-b border-border bg-background/80 backdrop-blur-sm">
        <div className="mx-auto flex h-14 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
          <Logo />
          <div className="hidden md:flex md:items-center md:gap-6">
            <NavLinks />
          </div>
          <MobileMenuButton className="md:hidden" />
        </div>
      </nav>
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {children}
      </main>
    </div>
  );
}
```

---

## shadcn/ui Components

### Setup and Key Components

shadcn/ui provides copy-paste components built on Radix UI and Tailwind.

```tsx
// Form with react-hook-form + zod + shadcn/ui
'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';

const teamMemberSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  role: z.enum(['admin', 'editor', 'viewer'], {
    required_error: 'Please select a role',
  }),
  bio: z.string().max(500).optional(),
});

type TeamMemberValues = z.infer<typeof teamMemberSchema>;

interface InviteMemberFormProps {
  onSubmit: (values: TeamMemberValues) => Promise<void>;
}

export function InviteMemberForm({ onSubmit }: InviteMemberFormProps) {
  const form = useForm<TeamMemberValues>({
    resolver: zodResolver(teamMemberSchema),
    defaultValues: { name: '', email: '', bio: '' },
  });

  async function handleSubmit(values: TeamMemberValues) {
    await onSubmit(values);
    form.reset();
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input placeholder="Jane Smith" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input type="email" placeholder="jane@company.com" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="role"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Role</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a role" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="admin">Admin</SelectItem>
                  <SelectItem value="editor">Editor</SelectItem>
                  <SelectItem value="viewer">Viewer</SelectItem>
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="bio"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Bio (optional)</FormLabel>
              <FormControl>
                <Textarea placeholder="Tell us about this person..." {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Sending Invite...' : 'Send Invite'}
        </Button>
      </form>
    </Form>
  );
}
```

### Data Table with Sorting and Filtering

```tsx
'use client';

import {
  type ColumnDef,
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  useReactTable,
  type SortingState,
} from '@tanstack/react-table';
import { useState } from 'react';
import { Input } from '@/components/ui/input';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface DataTableProps<T> {
  columns: ColumnDef<T>[];
  data: T[];
  searchColumn?: string;
  searchPlaceholder?: string;
}

export function DataTable<T>({
  columns,
  data,
  searchColumn,
  searchPlaceholder = 'Search...',
}: DataTableProps<T>) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [globalFilter, setGlobalFilter] = useState('');

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  return (
    <div className="space-y-4">
      {searchColumn && (
        <Input
          placeholder={searchPlaceholder}
          value={globalFilter}
          onChange={(e) => setGlobalFilter(e.target.value)}
          className="max-w-sm"
        />
      )}
      <div className="rounded-lg border border-border">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead
                    key={header.id}
                    onClick={header.column.getToggleSortingHandler()}
                    className={header.column.getCanSort() ? 'cursor-pointer select-none' : ''}
                  >
                    {flexRender(header.column.columnDef.header, header.getContext())}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow key={row.id}>
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center text-text-muted">
                  No results found.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
```

---

## Framer Motion Animations

### Core Patterns

```tsx
'use client';

import { motion, AnimatePresence } from 'framer-motion';

// Fade-in on mount
function FadeInSection({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  );
}

// AnimatePresence for mount/unmount animations
function NotificationToast({ notifications }: { notifications: Notification[] }) {
  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2">
      <AnimatePresence mode="popLayout">
        {notifications.map((n) => (
          <motion.div
            key={n.id}
            layout
            initial={{ opacity: 0, x: 100, scale: 0.95 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 100, scale: 0.95 }}
            transition={{ type: 'spring', stiffness: 400, damping: 30 }}
            className="rounded-lg border border-border bg-surface p-4 shadow-lg"
          >
            <p className="text-sm text-text-primary">{n.message}</p>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
```

### Staggered Children

```tsx
const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.06 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 8 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

function StaggeredList({ items }: { items: ListItem[] }) {
  return (
    <motion.ul variants={containerVariants} initial="hidden" animate="visible">
      {items.map((item) => (
        <motion.li key={item.id} variants={itemVariants} className="py-3 border-b border-border">
          <span className="text-text-primary">{item.label}</span>
        </motion.li>
      ))}
    </motion.ul>
  );
}
```

### Scroll-Triggered Animations

```tsx
import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';

function ScrollReveal({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 24 }}
      animate={isInView ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  );
}
```

### Layout Animations

```tsx
function ExpandableCard({ project }: { project: Project }) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <motion.div
      layout
      onClick={() => setIsExpanded(!isExpanded)}
      className="cursor-pointer rounded-lg border border-border bg-surface p-4"
      transition={{ layout: { duration: 0.25, ease: 'easeInOut' } }}
    >
      <motion.h3 layout="position" className="font-semibold text-text-primary">
        {project.name}
      </motion.h3>
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden"
          >
            <p className="mt-3 text-sm text-text-secondary">{project.description}</p>
            <div className="mt-4 flex gap-2">
              <StatusBadge status={project.status} />
              <span className="text-xs text-text-muted">{project.memberCount} members</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
```

### Performance Tips

```
FRAMER MOTION PERFORMANCE:
- Use layout="position" instead of layout when only position changes (cheaper).
- Avoid animating width/height directly -- prefer transform (scale, translate).
- Set willChange="transform" on elements that animate frequently.
- Use AnimatePresence mode="popLayout" for lists to avoid layout thrashing.
- Keep stagger delays under 0.08s to feel responsive, not slow.
- For scroll-triggered: use once: true to stop observing after first trigger.
- Avoid nesting motion.div more than 3 levels -- layout recalculation compounds.
```

---

## Dark Mode Implementation

### Complete ThemeProvider

```tsx
// lib/theme.tsx
'use client';

import { createContext, useContext, useEffect, useState, useCallback } from 'react';

type Theme = 'light' | 'dark' | 'system';
type ResolvedTheme = 'light' | 'dark';

interface ThemeContextValue {
  theme: Theme;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

// Inline script to prevent FOUC -- run before React hydrates
export function ThemeScript() {
  const script = `
    (function() {
      var stored = localStorage.getItem('theme');
      var theme = stored || 'system';
      var resolved = theme;
      if (theme === 'system') {
        resolved = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
      document.documentElement.classList.toggle('dark', resolved === 'dark');
      document.documentElement.style.colorScheme = resolved;
    })()
  `;
  return <script dangerouslySetInnerHTML={{ __html: script }} />;
}

function getSystemTheme(): ResolvedTheme {
  if (typeof window === 'undefined') return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window === 'undefined') return 'system';
    return (localStorage.getItem('theme') as Theme) || 'system';
  });

  const resolvedTheme: ResolvedTheme = theme === 'system' ? getSystemTheme() : theme;

  const setTheme = useCallback((newTheme: Theme) => {
    setThemeState(newTheme);
    localStorage.setItem('theme', newTheme);
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle('dark', resolvedTheme === 'dark');
    root.style.colorScheme = resolvedTheme;
  }, [resolvedTheme]);

  // Listen for system preference changes
  useEffect(() => {
    if (theme !== 'system') return;
    const mql = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = () => setThemeState('system'); // triggers re-resolve
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
```

### CSS Variables for Theming

```css
/* globals.css */
@import 'tailwindcss';

:root {
  --background: #ffffff;
  --surface: #f4f4f5;
  --border: #e4e4e7;
  --text-primary: #09090b;
  --text-secondary: rgba(9, 9, 11, 0.7);
  --accent: #3b82f6;
}

.dark {
  --background: #09090b;
  --surface: #111113;
  --border: #27272a;
  --text-primary: #fafafa;
  --text-secondary: rgba(250, 250, 250, 0.7);
  --accent: #3b82f6;
}

@theme {
  --color-background: var(--background);
  --color-surface: var(--surface);
  --color-border: var(--border);
  --color-text-primary: var(--text-primary);
  --color-text-secondary: var(--text-secondary);
  --color-accent: var(--accent);
}
```

### Theme Toggle Component

```tsx
'use client';

import { useTheme } from '@/lib/theme';
import { Monitor, Moon, Sun } from 'lucide-react';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  const options = [
    { value: 'light' as const, icon: Sun, label: 'Light' },
    { value: 'dark' as const, icon: Moon, label: 'Dark' },
    { value: 'system' as const, icon: Monitor, label: 'System' },
  ];

  return (
    <div className="flex items-center gap-1 rounded-lg border border-border bg-surface p-1">
      {options.map(({ value, icon: Icon, label }) => (
        <button
          key={value}
          onClick={() => setTheme(value)}
          aria-label={`Switch to ${label} theme`}
          className={`rounded-md p-1.5 transition-colors ${
            theme === value
              ? 'bg-accent text-white'
              : 'text-text-secondary hover:text-text-primary'
          }`}
        >
          <Icon className="h-4 w-4" />
        </button>
      ))}
    </div>
  );
}
```

### Root Layout Integration

```tsx
// app/layout.tsx
import { ThemeProvider, ThemeScript } from '@/lib/theme';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <ThemeScript />
      </head>
      <body className="bg-background text-text-primary antialiased">
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

---

## Quick Reference

```
COMPONENT DECISION TREE:
  Needs interactivity (clicks, inputs, state)?  --> 'use client'
  Fetches data on the server?                    --> Server Component (default)
  Renders static content?                        --> Server Component (default)
  Uses browser APIs (localStorage, window)?      --> 'use client'
  Third-party lib requires useEffect?            --> 'use client'

STATE MANAGEMENT DECISION TREE:
  Local UI state (toggle, form input)?           --> useState
  Shared across sibling components?              --> Zustand (lightweight store)
  Server data (API responses, DB queries)?       --> TanStack Query
  URL-driven state (filters, pagination)?        --> useSearchParams / nuqs
  Form state with validation?                    --> react-hook-form + zod

PERFORMANCE CHECKLIST:
  [ ] Server Components for data-heavy views
  [ ] Dynamic imports for heavy client components
  [ ] useMemo only for genuinely expensive computations
  [ ] useCallback only for stable references passed to memoized children
  [ ] Image optimization with next/image
  [ ] Prefetch on hover/focus for likely navigation targets
  [ ] Suspense boundaries for independent loading states
```
