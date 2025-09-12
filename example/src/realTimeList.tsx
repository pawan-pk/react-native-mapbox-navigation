import { useEffect, useState } from 'react';
import type { Participant } from './Participant';
import { dummyImageURLs } from './dummyImageURLs';
import { Points } from './Points';
export default function useRandomUsers() {
  const startOrigin = { latitude: 28.4212, longitude: 70.2989 };
  const destination = { latitude: 31.5204, longitude: 74.3587 };
  const [participants, setParticipants] = useState<Participant[]>([]);

  useEffect(() => {
    const users: Participant[] = Array.from({ length: 10 }).map((_, idx) => ({
      id: `user-${idx + 1}`,
      userMail: `user${idx + 1}@example.com`,
      coverImage: '',
      displayName: `User ${idx + 1}`,
      imageUrl: dummyImageURLs[idx] ?? 'https://picsum.photos/id/112/400/300',
      isBenzifiMember: false,
      nation: 'AE',
      userName: `user${idx + 1}`,
      lat: startOrigin.latitude,
      lng: startOrigin.longitude,
    }));
    setParticipants(users);
  }, [
    startOrigin.latitude,
    startOrigin.longitude,
    destination.latitude,
    destination.longitude,
  ]);

  // Track user index along the path
  useEffect(() => {
    const interval = setInterval(() => {
      setParticipants((prev) =>
        prev.map((user, idx) => {
          // Each user has an implicit "path index"
          // Example: user-1 => pathIndex = tick + 0, user-2 => tick + 1
          const currentTick = Date.now() / 5000; // every 5 sec
          const step = Math.floor(currentTick) + idx;

          const pathIndex = step % Points.length; // loop around
          const [lng, lat] = Points[pathIndex]!;

          return {
            ...user,
            lat,
            lng,
          };
        })
      );
    }, 5000);
    return () => clearInterval(interval);
  }, [
    startOrigin.latitude,
    startOrigin.longitude,
    destination.latitude,
    destination.longitude,
  ]);
  return participants;
}
