<?php

namespace Database\Seeders\Concerns;

use Carbon\CarbonImmutable;

trait SeedsHistoryRange
{
    /** Inclusive lower bound (UTC). */
    protected function historyStartUtc(): CarbonImmutable
    {
        return CarbonImmutable::create(2025, 1, 1, 0, 0, 0, 'UTC');
    }

    /** Inclusive upper bound (UTC). */
    protected function historyEndUtc(): CarbonImmutable
    {
        return CarbonImmutable::create(2026, 5, 11, 23, 59, 59, 'UTC');
    }

    /**
     * Deterministic signup time for dummy user index, biased so more accounts fall in the recent part of the window (better admin charts).
     *
     * @param  int  $index  0 .. $total - 1
     */
    protected function biasedUserSignupAt(int $index, int $total, int $userId): CarbonImmutable
    {
        $start = $this->historyStartUtc();
        $end = $this->historyEndUtc();
        $rangeSeconds = max(1, $end->getTimestamp() - $start->getTimestamp());

        $t = $total <= 1 ? 0.0 : ($index / ($total - 1));
        $ratio = 1 - (1 - $t) ** 2;
        $baseOffset = (int) ($ratio * $rangeSeconds);

        $jitterCap = max(1, min(86400 * 3, (int) ($rangeSeconds * 0.002)));
        $jitter = abs(crc32('dummy-user-jitter|'.$userId)) % $jitterCap;

        $ts = $start->addSeconds(min($rangeSeconds, $baseOffset + $jitter));

        if ($ts->lessThan($start)) {
            return $start;
        }
        if ($ts->greaterThan($end)) {
            return $end;
        }

        return $ts;
    }

    /**
     * Deterministic moment at or after $notBefore and at or before history end.
     */
    protected function contentCreatedAtUtc(CarbonImmutable $notBefore, string $salt, int $iteration): CarbonImmutable
    {
        $end = $this->historyEndUtc();
        $floor = $notBefore->greaterThan($this->historyStartUtc()) ? $notBefore : $this->historyStartUtc();
        if ($floor->greaterThan($end)) {
            return $end;
        }

        $rangeSeconds = max(1, $end->getTimestamp() - $floor->getTimestamp());
        $offset = abs(crc32('content|'.$salt.'|'.$iteration)) % $rangeSeconds;

        return $floor->addSeconds($offset);
    }

    /**
     * Post timestamps skewed toward the end of the window so "last 30 days" admin charts stay populated.
     */
    protected function postPublishedAtUtc(CarbonImmutable $notBefore, string $salt, int $iteration): CarbonImmutable
    {
        $end = $this->historyEndUtc();
        $floor = $notBefore->greaterThan($this->historyStartUtc()) ? $notBefore : $this->historyStartUtc();
        if ($floor->greaterThan($end)) {
            return $end;
        }

        $recentStart = $end->subDays(60);
        if ($recentStart->lessThan($floor)) {
            $recentStart = $floor;
        }

        $preferRecent = (abs(crc32('post-recent|'.$salt.'|'.$iteration)) % 100) < 80;
        $rangeStart = $preferRecent ? $recentStart : $floor;
        $rangeSeconds = max(1, $end->getTimestamp() - $rangeStart->getTimestamp());
        $offset = abs(crc32('post|'.$salt.'|'.$iteration)) % $rangeSeconds;

        return $rangeStart->addSeconds($offset);
    }

}
