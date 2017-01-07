FROM lsiobase/alpine
MAINTAINER sparklyballs

# package versions
ENV TOMCAT_VERSION 8.5.9

# environment settings
ENV CATALINA_HOME="/usr/local/tomcat" \
JAVA_HOME="/usr/lib/jvm/java-1.8-openjdk/jre" LANG="C.UTF-8"
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR
ENV PATH $CATALINA_HOME/bin:$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib

# setting workdir
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

# add local files
COPY docker-java-home /usr/local/bin/docker-java-home

# install java
RUN \
 chmod +x \
	/usr/local/bin/docker-java-home && \
 apk add --no-cache \
	openjdk8-jre && \
 [ "$JAVA_HOME" = "$(docker-java-home)" ] && \

# install build packages
 apk add --no-cache --virtual=build-dependencies \
	apr-dev \
	curl \
	gcc \
	libc-dev \
	make \
	openjdk8 \
	openssl-dev \
	tar && \

# install tomcat
 TOMCAT_MAJOR=${TOMCAT_VERSION::1} && \
 curl -o \
 "$CATALINA_HOME/tomcat.tar.gz" -L \
	"https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz" && \
 tar -xf tomcat.tar.gz --exclude=bin/*.bat --strip-components=1 && \
 rm tomcat.tar.gz* && \

# compile tomcat native
 mkdir -p \
	/tmp/tomcat && \
 tar -xf \
 bin/tomcat-native.tar.gz -C \
	/tmp/tomcat --strip-components=1 && \
 rm bin/tomcat-native.tar.gz && \
 cd /tmp/tomcat/native && \
 export CATALINA_HOME="$PWD" && \
 ./configure \
	--libdir="$TOMCAT_NATIVE_LIBDIR" \
	--prefix="$CATALINA_HOME" \
	--with-apr="$(which apr-1-config)" \
	--with-java-home="$(docker-java-home)" \
	--with-ssl=yes && \
 make && \
 make install && \
 TOMCAT_DEPS="$( \
	scanelf --needed --nobanner --recursive "$TOMCAT_NATIVE_LIBDIR" \
	| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' | sort -u \
	| xargs -r apk info --installed | sort -u )" && \
 apk add $TOMCAT_DEPS && \

# cleanup
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/tmp/*

EXPOSE 8080
