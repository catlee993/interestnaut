export namespace bindings {
	
	export class BookWithSavedStatus {
	    title: string;
	    author: string;
	    key: string;
	    cover_path: string;
	    year?: number;
	    subjects?: string[];
	
	    static createFrom(source: any = {}) {
	        return new BookWithSavedStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.title = source["title"];
	        this.author = source["author"];
	        this.key = source["key"];
	        this.cover_path = source["cover_path"];
	        this.year = source["year"];
	        this.subjects = source["subjects"];
	    }
	}
	export class Developer {
	    id: number;
	    name: string;
	    slug?: string;
	
	    static createFrom(source: any = {}) {
	        return new Developer(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.slug = source["slug"];
	    }
	}
	export class Publisher {
	    id: number;
	    name: string;
	    slug?: string;
	
	    static createFrom(source: any = {}) {
	        return new Publisher(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.slug = source["slug"];
	    }
	}
	export class Genre {
	    id: number;
	    name: string;
	    slug?: string;
	
	    static createFrom(source: any = {}) {
	        return new Genre(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.slug = source["slug"];
	    }
	}
	export class PlatformDetails {
	    id: number;
	    name: string;
	    slug: string;
	
	    static createFrom(source: any = {}) {
	        return new PlatformDetails(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.slug = source["slug"];
	    }
	}
	export class Platform {
	    id?: number;
	    name: string;
	    slug?: string;
	    platform?: PlatformDetails;
	
	    static createFrom(source: any = {}) {
	        return new Platform(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.slug = source["slug"];
	        this.platform = this.convertValues(source["platform"], PlatformDetails);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class Screenshot {
	    id: number;
	    image: string;
	
	    static createFrom(source: any = {}) {
	        return new Screenshot(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.image = source["image"];
	    }
	}
	export class GameWithSavedStatus {
	    id: number;
	    name: string;
	    slug: string;
	    released?: string;
	    background_image?: string;
	    rating: number;
	    ratings_count: number;
	    playtime: number;
	    description?: string;
	    short_screenshots?: Screenshot[];
	    platforms?: Platform[];
	    genres?: Genre[];
	    developers?: Developer[];
	    publishers?: Publisher[];
	    isSaved: boolean;
	    isInWatchlist: boolean;
	
	    static createFrom(source: any = {}) {
	        return new GameWithSavedStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.slug = source["slug"];
	        this.released = source["released"];
	        this.background_image = source["background_image"];
	        this.rating = source["rating"];
	        this.ratings_count = source["ratings_count"];
	        this.playtime = source["playtime"];
	        this.description = source["description"];
	        this.short_screenshots = this.convertValues(source["short_screenshots"], Screenshot);
	        this.platforms = this.convertValues(source["platforms"], Platform);
	        this.genres = this.convertValues(source["genres"], Genre);
	        this.developers = this.convertValues(source["developers"], Developer);
	        this.publishers = this.convertValues(source["publishers"], Publisher);
	        this.isSaved = source["isSaved"];
	        this.isInWatchlist = source["isInWatchlist"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	
	export class MovieWithSavedStatus {
	    id: number;
	    title: string;
	    overview: string;
	    director: string;
	    writer: string;
	    poster_path: string;
	    release_date: string;
	    vote_average: number;
	    vote_count: number;
	    genres: string[];
	
	    static createFrom(source: any = {}) {
	        return new MovieWithSavedStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.title = source["title"];
	        this.overview = source["overview"];
	        this.director = source["director"];
	        this.writer = source["writer"];
	        this.poster_path = source["poster_path"];
	        this.release_date = source["release_date"];
	        this.vote_average = source["vote_average"];
	        this.vote_count = source["vote_count"];
	        this.genres = source["genres"];
	    }
	}
	
	
	
	
	export class TVShowWithSavedStatus {
	    id: number;
	    name: string;
	    overview: string;
	    director: string;
	    writer: string;
	    poster_path: string;
	    first_air_date: string;
	    vote_average: number;
	    vote_count: number;
	    genres: string[];
	    isSaved?: boolean;
	
	    static createFrom(source: any = {}) {
	        return new TVShowWithSavedStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.overview = source["overview"];
	        this.director = source["director"];
	        this.writer = source["writer"];
	        this.poster_path = source["poster_path"];
	        this.first_air_date = source["first_air_date"];
	        this.vote_average = source["vote_average"];
	        this.vote_count = source["vote_count"];
	        this.genres = source["genres"];
	        this.isSaved = source["isSaved"];
	    }
	}

}

export namespace session {
	
	export enum Outcome {
	    liked = "liked",
	    disliked = "disliked",
	    skipped = "skipped",
	    added = "added",
	    pending = "pending",
	}
	export class Book {
	    title: string;
	    author: string;
	    cover_path: string;
	
	    static createFrom(source: any = {}) {
	        return new Book(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.title = source["title"];
	        this.author = source["author"];
	        this.cover_path = source["cover_path"];
	    }
	}
	export class Movie {
	    title: string;
	    director: string;
	    writer: string;
	    poster_path: string;
	
	    static createFrom(source: any = {}) {
	        return new Movie(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.title = source["title"];
	        this.director = source["director"];
	        this.writer = source["writer"];
	        this.poster_path = source["poster_path"];
	    }
	}
	export class TVShow {
	    title: string;
	    director: string;
	    writer: string;
	    poster_path: string;
	
	    static createFrom(source: any = {}) {
	        return new TVShow(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.title = source["title"];
	        this.director = source["director"];
	        this.writer = source["writer"];
	        this.poster_path = source["poster_path"];
	    }
	}
	export class VideoGame {
	    title: string;
	    developer: string;
	    publisher: string;
	    platforms: string[];
	    cover_path: string;
	
	    static createFrom(source: any = {}) {
	        return new VideoGame(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.title = source["title"];
	        this.developer = source["developer"];
	        this.publisher = source["publisher"];
	        this.platforms = source["platforms"];
	        this.cover_path = source["cover_path"];
	    }
	}

}

export namespace spotify {
	
	export class Image {
	    url: string;
	    height: number;
	    width: number;
	
	    static createFrom(source: any = {}) {
	        return new Image(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.url = source["url"];
	        this.height = source["height"];
	        this.width = source["width"];
	    }
	}
	export class Album {
	    id: string;
	    name: string;
	    images: Image[];
	
	    static createFrom(source: any = {}) {
	        return new Album(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.images = this.convertValues(source["images"], Image);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class Artist {
	    id: string;
	    name: string;
	    genres: string[];
	
	    static createFrom(source: any = {}) {
	        return new Artist(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.genres = source["genres"];
	    }
	}
	
	export class Track {
	    id: string;
	    name: string;
	    artists: Artist[];
	    album: Album;
	    preview_url: string;
	    uri: string;
	
	    static createFrom(source: any = {}) {
	        return new Track(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.artists = this.convertValues(source["artists"], Artist);
	        this.album = this.convertValues(source["album"], Album);
	        this.preview_url = source["preview_url"];
	        this.uri = source["uri"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class SavedTrackItem {
	    track?: Track;
	    added_at: string;
	
	    static createFrom(source: any = {}) {
	        return new SavedTrackItem(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.track = this.convertValues(source["track"], Track);
	        this.added_at = source["added_at"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class SavedTracks {
	    items: SavedTrackItem[];
	    total: number;
	    limit: number;
	    offset: number;
	    next: string;
	    previous: string;
	
	    static createFrom(source: any = {}) {
	        return new SavedTracks(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.items = this.convertValues(source["items"], SavedTrackItem);
	        this.total = source["total"];
	        this.limit = source["limit"];
	        this.offset = source["offset"];
	        this.next = source["next"];
	        this.previous = source["previous"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class SimpleTrack {
	    id: string;
	    name: string;
	    artist: string;
	    artistId: string;
	    album: string;
	    albumId: string;
	    albumArtUrl: string;
	    previewUrl: string;
	    uri: string;
	
	    static createFrom(source: any = {}) {
	        return new SimpleTrack(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.artist = source["artist"];
	        this.artistId = source["artistId"];
	        this.album = source["album"];
	        this.albumId = source["albumId"];
	        this.albumArtUrl = source["albumArtUrl"];
	        this.previewUrl = source["previewUrl"];
	        this.uri = source["uri"];
	    }
	}
	export class SuggestedTrackInfo {
	    id: string;
	    name: string;
	    artist: string;
	    album: string;
	    previewUrl?: string;
	    albumArtUrl?: string;
	    reason?: string;
	    uri?: string;
	
	    static createFrom(source: any = {}) {
	        return new SuggestedTrackInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.artist = source["artist"];
	        this.album = source["album"];
	        this.previewUrl = source["previewUrl"];
	        this.albumArtUrl = source["albumArtUrl"];
	        this.reason = source["reason"];
	        this.uri = source["uri"];
	    }
	}
	
	export class UserProfile {
	    id: string;
	    display_name: string;
	    email: string;
	    country: string;
	    genres: string[];
	    images: Image[];
	
	    static createFrom(source: any = {}) {
	        return new UserProfile(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.display_name = source["display_name"];
	        this.email = source["email"];
	        this.country = source["country"];
	        this.genres = source["genres"];
	        this.images = this.convertValues(source["images"], Image);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}

}

