export interface Participant {
  id: string;
  userMail: string;
  coverImage: string;
  displayName: string;
  imageUrl: string;
  isBenzifiMember: boolean;
  nation: string;
  userName: string;
  lat: number; // starting latitude
  lng: number; // starting longitude
}
