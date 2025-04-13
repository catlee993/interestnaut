export namespace session {
	
	export enum Outcome {
	    liked = "liked",
	    disliked = "disliked",
	    skipped = "skipped",
	    added = "added",
	    pending = "pending",
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

