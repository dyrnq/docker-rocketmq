#!/usr/bin/env bash
set -Eeo pipefail

base_image="${base_image:-}"
version="${version:-5.3.1}";
push="${push:-false}"
repo="${repo:-dyrnq}"
image_name="${image_name:-rocketmq}"
platforms="${platforms:-linux/amd64,linux/arm64/v8}"
curl_opts="${curl_opts:-}"
while [ $# -gt 0 ]; do
    case "$1" in
        --base-image|--base)
            base_image="$2"
            shift
            ;;
        --version|--ver)
            version="$2"
            shift
            ;;
        --push)
            push="$2"
            shift
            ;;
        --curl-opts)
            curl_opts="$2"
            shift
            ;;
        --platforms)
            platforms="$2"
            shift
            ;;
        --repo)
            repo="$2"
            shift
            ;;
        --image-name|--image)
            image_name="$2"
            shift
            ;;
        --*)
            echo "Illegal option $1"
            ;;
    esac
    shift $(( $# > 0 ? 1 : 0 ))
done


latest=$(cat latest);
echo "$latest";
latest_tag=""


# if [ "$latest" = "$version" ]; then
#     echo "latest version is $latest"
#     latest_tag="${latest_tag} --tag $repo/$image_name:latest"
# fi


if [[ "${base_image}" =~ "openjdk8" ]]; then
    if [[ "${version}" = "${latest}" ]]; then
        latest_tag="${latest_tag} --tag $repo/$image_name:latest"
    fi
    latest_tag="${latest_tag} --tag $repo/$image_name:$version"
    latest_tag="${latest_tag} --tag $repo/$image_name:${version}-jdk8"
elif [[ "${base_image}" =~ "eclipse-temurin:8u" ]]; then
    latest_tag="${latest_tag} --tag $repo/$image_name:${version}-jdk8-noble"
elif [[ "${base_image}" =~ "eclipse-temurin:21" ]]; then
    latest_tag="${latest_tag} --tag $repo/$image_name:${version}-jdk21-noble"
    latest_tag="${latest_tag} --tag $repo/$image_name:${version}-jdk21"
fi


docker buildx build \
--platform ${platforms} \
--output "type=image,push=${push}" \
--file ./Dockerfile . \
--build-arg version="${version}" \
--build-arg BASE_IMAGE="${base_image}" \
$latest_tag






